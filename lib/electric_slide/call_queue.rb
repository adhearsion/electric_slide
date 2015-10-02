# encoding: utf-8

# The default agent strategy
require 'electric_slide/agent_strategy/longest_idle'

class ElectricSlide
  class CallQueue
    MissingAgentError = Class.new(StandardError)
    DuplicateAgentError = Class.new(StandardError)

    include Celluloid
    ENDED_CALL_EXCEPTIONS = [
      Adhearsion::Call::Hangup,
      Adhearsion::Call::ExpiredError,
      Adhearsion::Call::CommandTimeout,
      Celluloid::DeadActorError,
      Punchblock::ProtocolError
    ]

    CONNECTION_TYPES = [
      :call,
      :bridge,
    ].freeze

    AGENT_RETURN_METHODS = [
      :auto,
      :manual,
    ].freeze

    def self.work(*args)
      self.supervise *args
    end

    def initialize(opts = {})
      agent_strategy   = opts[:agent_strategy]  || AgentStrategy::LongestIdle
      @connection_type = opts[:connection_type] || :call
      @agent_return_method = opts[:agent_return_method] || :auto

      raise ArgumentError, "Invalid connection type; must be one of #{CONNECTION_TYPES.join ','}" unless CONNECTION_TYPES.include? @connection_type
      raise ArgumentError, "Invalid requeue method; must be one of #{AGENT_RETURN_METHODS.join ','}" unless AGENT_RETURN_METHODS.include? @agent_return_method

      @agents = []      # Needed to keep track of global list of agents
      @queue = []       # Calls waiting for an agent

      @strategy = agent_strategy.new
    end

    # Checks whether an agent is available to take a call
    # @return [Boolean] True if an agent is available
    def agent_available?
      @strategy.agent_available?
    end

    # Returns information about the number of available agents
    # The data returned depends on the AgentStrategy in use.
    # The data will always include a :total count of the agents available
    # @return [Hash] Summary information about agents available, depending on strategy
    def available_agent_summary
      # TODO: Make this a delegator?
      @strategy.available_agent_summary
    end

    # Assigns the first available agent, marking the agent :on_call
    # @return {Agent}
    def checkout_agent
      agent = @strategy.checkout_agent
      if agent
        agent.presence = :on_call
        agent.callback :presence_change, self, agent.call, agent.presence
      end
      agent
    end

    # Returns a copy of the set of agents that are known to the queue
    # @return [Array] Array of {Agent} objects
    def get_agents
      @agents.dup
    end

    # Returns a copy of the set of calls waiting to be answered that are known to the queue
    # @return [Array] Array of Adhearsion::Call objects
    def get_queued_calls
      @queue.dup
    end

    # Finds an agent known to the queue by that agent's ID
    # @param [String] id The ID of the agent to locate
    # @return [Agent, Nil] {Agent} object if found, Nil otherwise
    def get_agent(id)
      @agents.detect { |agent| agent.id == id }
    end

    # Registers an agent to the queue
    # @param [Agent] agent The agent to be added to the queue
    # @raise ArgumentError if the agent is malformed
    # @raise DuplicateAgentError if this agent ID already exists
    # @see #update_agent
    def add_agent(agent)
      abort ArgumentError.new("#add_agent called with nil object") if agent.nil?
      abort DuplicateAgentError.new("Agent is already in the queue") if get_agent(agent.id)

      case @connection_type
      when :call
        abort ArgumentError.new("Agent has no callable address") unless agent.address
      when :bridge
        bridged_agent_health_check agent
      end

      logger.info "Adding agent #{agent} to the queue"
      @agents << agent
      @strategy << agent if agent.presence == :available
      agent.callback :presence_change, self, agent.call, agent.presence

      check_for_connections
    end

    # Marks an agent as available to take a call. To be called after an agent completes a call
    # and is ready to take the next call.
    # @param [Agent] agent The {Agent} that is being returned to the queue
    # @param [Symbol] status The {Agent}'s new status
    # @param [String, Optional] address The {Agent}'s address. Only specified if it has changed
    def return_agent(agent, status = :available, address = nil)
      logger.debug "Returning #{agent} to the queue"

      abort MissingAgentError.new('Agent is not in the queue. Unable to return agent.') unless get_agent(agent.id)

      agent.presence = status
      agent.callback :presence_change, self, agent.call, agent.presence
      agent.address = address if address

      case agent.presence
      when :available
        bridged_agent_health_check agent

        @strategy << agent
        check_for_connections
      when :unavailable
        @strategy.delete agent
      end
      agent
    end

    # Removes an agent from the queue entirely
    # @param [Agent] agent The {Agent} to be removed from the queue
    # @return [Agent, Nil] The Agent object if removed, Nil otherwise
    def remove_agent(agent)
      @strategy.delete agent
      @agents.delete agent
      logger.info "Removing agent #{agent} from the queue"
    rescue Adhearsion::Call::ExpiredError
    end

    # Checks to see if any callers are waiting for an agent and attempts to connect them to
    # an available agent
    def check_for_connections
      connect checkout_agent, get_next_caller while call_waiting? && agent_available?
    end

    # Add a call to the head of the queue. Among other reasons, this is used when a caller is sent
    # to an agent, but the connection fails because the agent is not available.
    # @param [Adhearsion::Call] call Caller to be added to the queue
    def priority_enqueue(call)
      # Don't reset the enqueue time in case this is a re-insert on agent failure
      call[:electric_slide_enqueued_at] ||= DateTime.now
      call.on_end { remove_call call }
      @queue.unshift call

      check_for_connections
    end

    # Add a call to the end of the queue, the normal FIFO queue behavior
    # @param [Adhearsion::Call] call Caller to be added to the queue
    def enqueue(call)
      ignoring_ended_calls do
        logger.info "Adding call from #{remote_party call} to the queue"
        call[:electric_slide_enqueued_at] = DateTime.now
        call.on_end { remove_call call }
        @queue << call unless @queue.include? call

        check_for_connections
      end
    end

    # Remove a waiting call from the queue. Used if the caller hangs up or is otherwise removed.
    # @param [Adhearsion::Call] call Caller to be removed from the queue
    def remove_call(call)
      ignoring_ended_calls do
        unless call[:electric_slide_connected_at]
          logger.info "Caller #{remote_party call} has abandoned the queue"
        end
      end
      @queue.delete call
    end

    # Connect an {Agent} to a caller
    # @param [Agent] agent Agent to be connected
    # @param [Adhearsion::Call] call Caller to be connected
    def connect(agent, queued_call)
      unless queued_call.active?
        logger.warn "Inactive queued call found in #connect"
        return_agent agent
      end

      logger.info "Connecting #{agent} with #{remote_party queued_call}"
      case @connection_type
      when :call
        call_agent agent, queued_call
      when :bridge
        unless agent.call && agent.call.active?
          logger.warn "Inactive agent call found in #connect, returning caller to queue"
          priority_enqueue queued_call
        end
        bridge_agent agent, queued_call
      end
    rescue *ENDED_CALL_EXCEPTIONS
      ignoring_ended_calls do
        if queued_call.active?
          logger.warn "Dead call exception in #connect but queued_call still alive, reinserting into queue"
          priority_enqueue queued_call
        end
      end
      ignoring_ended_calls do
        if agent.call && agent.call.active?
          logger.warn "Dead call exception in #connect but agent call still alive, reinserting into queue"
          agent.callback :connection_failed, self, agent.call, queued_call

          return_agent agent
        end
      end
    end

    def conditionally_return_agent(agent, return_method = @agent_return_method)
      raise ArgumentError, "Invalid requeue method; must be one of #{AGENT_RETURN_METHODS.join ','}" unless AGENT_RETURN_METHODS.include? return_method

      if agent && @agents.include?(agent) && agent.on_call? && return_method == :auto
        logger.info "Returning agent #{agent.id} to queue"
        return_agent agent
      else
        logger.debug "Not returning agent #{agent.inspect} to the queue"
        return_agent agent, :after_call
      end
    end

    # Returns the next waiting caller
    # @return [Adhearsion::Call] The next waiting caller
    def get_next_caller
      @queue.shift
    end

    # Checks whether any callers are waiting
    # @return [Boolean] True if a caller is waiting
    def call_waiting?
      @queue.length > 0
    end

    # Returns the number of callers waiting in the queue
    # @return [Fixnum]
    def calls_waiting
      @queue.length
    end

  private

    # Get the caller ID of the remote party.
    # If this is an OutboundCall, use Call#to
    # Otherwise, use Call#from
    def remote_party(call)
      call.is_a?(Adhearsion::OutboundCall) ? call.to : call.from
    end

    # @private
    def ignoring_ended_calls
      yield
    rescue *ENDED_CALL_EXCEPTIONS
      # This actor may previously have been shut down due to the call ending
    end

    def call_agent(agent, queued_call)
      agent_call = Adhearsion::OutboundCall.new
      agent_call[:agent]  = agent
      agent_call[:queued_call] = queued_call

      agent.call = agent_call

      # Stash the caller ID so we don't have to try to get it from a dead call object later
      queued_caller_id = remote_party queued_call

      # The call controller is actually run by #dial, here we skip joining if we do not have one
      dial_options = agent.dial_options_for(self, queued_call)
      unless dial_options[:confirm]
        agent_call.on_answer { ignoring_ended_calls { agent_call.join queued_call.uri if queued_call.active? } }
      end

      # Disconnect agent if caller hangs up before agent answers
      queued_call.on_end { ignoring_ended_calls { agent_call.hangup } }

      agent_call.on_unjoined do
       ignoring_ended_calls { agent_call.hangup }
       ignoring_ended_calls { queued_call.hangup }
      end

      # Track whether the agent actually talks to the queued_call
      connected = false
      queued_call.register_tmp_handler :event, Punchblock::Event::Joined do |event|
        connected = true
        queued_call[:electric_slide_connected_at] = event.timestamp
      end

      agent_call.on_end do |end_event|
        # Ensure we don't return an agent that was removed or paused
        conditionally_return_agent agent

        agent.call = nil

        agent.callback :disconnect, self, agent_call, queued_call

        unless connected
          if queued_call.alive? && queued_call.active?
            ignoring_ended_calls { priority_enqueue queued_call }
            agent.callback :connection_failed, self, agent_call, queued_call

            logger.warn "Call did not connect to agent! Agent #{agent.id} call ended with #{end_event.reason}; reinserting caller #{queued_caller_id} into queue"
          else
            logger.warn "Caller #{queued_caller_id} hung up before being connected to an agent."
          end
        end
      end

      agent.callback :connect, self, agent_call, queued_call

      agent_call.execute_controller_or_router_on_answer dial_options.delete(:confirm), dial_options.delete(:confirm_metadata)

      agent_call.dial agent.address, dial_options
    end

    def bridge_agent(agent, queued_call)
      # Stash caller ID to make log messages work even if calls end
      queued_caller_id = remote_party queued_call
      agent.call[:queued_call] = queued_call

      agent.call.register_tmp_handler :event, Punchblock::Event::Unjoined do
        agent.callback :disconnect, self, agent.call, queued_call
        ignoring_ended_calls { queued_call.hangup }
        ignoring_ended_calls { conditionally_return_agent agent if agent.call && agent.call.active? }
        agent.call[:queued_call] = nil if agent.call
      end

      queued_call.register_tmp_handler :event, Punchblock::Event::Joined do |event|
        queued_call[:electric_slide_connected_at] = event.timestamp
      end

      agent.callback :connect, self, agent.call, queued_call

      agent.join queued_call if queued_call.active?
    rescue *ENDED_CALL_EXCEPTIONS
      ignoring_ended_calls do
        if agent.call && agent.call.active?
          agent.callback :connection_failed, self, agent.call, queued_call

          logger.info "Caller #{queued_caller_id} failed to connect to Agent #{agent.id} due to caller hangup"
          conditionally_return_agent agent, :auto
        end
      end

      ignoring_ended_calls do
        if queued_call.active?
          priority_enqueue queued_call
          logger.warn "Call failed to connect to Agent #{agent.id} due to agent hangup; reinserting caller #{queued_caller_id} into queue"
        end
      end
    end

    # @private
    def bridged_agent_health_check(agent)
      if agent.presence == :available && @connection_type == :bridge
        abort ArgumentError.new("Agent has no active call") unless agent.call && agent.call.active?
        unless agent.call[:electric_slide_callback_set]
          agent.call[:electric_slide_callback_set] = true
          queue = self
          agent.call.on_end do
            agent.call = nil
            queue.return_agent agent, :unavailable
          end
        end
      end
    end
  end
end
