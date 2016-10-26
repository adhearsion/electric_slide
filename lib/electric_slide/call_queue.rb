# encoding: utf-8

# The default agent strategy
require 'electric_slide/agent_strategy/longest_idle'

class ElectricSlide
  class CallQueue
    include Celluloid

    ENDED_CALL_EXCEPTIONS = [
      Adhearsion::Call::Hangup,
      Adhearsion::Call::ExpiredError,
      Adhearsion::Call::CommandTimeout,
      Celluloid::DeadActorError,
      Adhearsion::ProtocolError
    ]

    CONNECTION_TYPES = [
      :call,
      :bridge,
    ].freeze

    AGENT_RETURN_METHODS = [
      :auto,
      :manual,
    ].freeze

    Error = Class.new(StandardError)

    MissingAgentError = Class.new(Error)
    DuplicateAgentError = Class.new(Error)

    class InvalidConnectionType < Error
      def message
        "Invalid connection type; must be one of #{CONNECTION_TYPES.join ','}"
      end
    end

    class InvalidRequeueMethod < Error
      def message
        "Invalid requeue method; must be one of #{AGENT_RETURN_METHODS.join ','}"
      end
    end

    attr_reader :agent_strategy, :connection_type, :agent_return_method

    def self.valid_with?(attrs = {})
      return false unless Hash === attrs

      if agent_strategy = attrs[:agent_strategy]
        begin
          agent_strategy.new
        rescue Exception
          return false
        end
      end
      if connection_type = attrs[:connection_type]
        return false unless valid_connection_type? connection_type
      end
      if agent_return_method = attrs[:agent_return_method]
        return false unless valid_agent_return_method? agent_return_method
      end

      true
    end

    def self.valid_connection_type?(connection_type)
      CONNECTION_TYPES.include? connection_type
    end

    def self.valid_agent_return_method?(agent_return_method)
      AGENT_RETURN_METHODS.include? agent_return_method
    end

    def initialize(opts = {})
      @agents = []      # Needed to keep track of global list of agents
      @queue = []       # Calls waiting for an agent

      update(
        agent_strategy: opts[:agent_strategy] || AgentStrategy::LongestIdle,
        connection_type: opts[:connection_type] || :call,
        agent_return_method: opts[:agent_return_method] || :auto
      )
    end

    def update(attrs)
      attrs.each do |attr, value|
        setter = "#{attr}="
        send setter, value if respond_to?(setter)
      end unless attrs.nil?
    end

    def agent_strategy=(new_agent_strategy)
      @agent_strategy = new_agent_strategy

      @strategy = @agent_strategy.new
      @agents.each do |agent|
        return_agent agent, agent.presence
      end

      @agent_strategy
    end

    def connection_type=(new_connection_type)
      abort InvalidConnectionType.new unless CallQueue.valid_connection_type? new_connection_type
      @connection_type = new_connection_type
    end

    def agent_return_method=(new_agent_return_method)
      abort InvalidRequeueMethod.new unless CallQueue.valid_agent_return_method? new_agent_return_method
      @agent_return_method = new_agent_return_method
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
        agent.update_presence(:on_call)
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

      agent.queue = current_actor
      accept_agent! agent

      logger.info "Adding agent #{agent} to the queue"
      @agents << agent
      @strategy << agent if agent.presence == :available
      # Fake the presence callback since this is a new agent
      agent.callback :presence_change, current_actor, agent.call, agent.presence, :unavailable

      async.check_for_connections
    end

    # Updates a queued agent's attributes
    def update_agent(agent, agent_attrs)
      abort ArgumentError.new('Agent must not be `nil`') unless agent
      unless get_agent(agent.id)
        abort MissingAgentError.new('Agent is not in the queue')
      end

      # check if the agent is allowed to have the given set of attributes using
      # a dupe, to preserve the state of the original in case of failure
      agent.dup.tap do |double_agent|
        double_agent.update agent_attrs
        accept_agent! double_agent
      end

      agent.update agent_attrs
      return_agent agent, agent.presence
    end

    # Marks an agent as available to take a call. To be called after an agent completes a call
    # and is ready to take the next call.
    # @param [Agent] agent The {Agent} that is being returned to the queue
    # @param [Symbol] new_presence The {Agent}'s new presence
    # @param [String, Optional] address The {Agent}'s address. Only specified if it has changed
    def return_agent(agent, new_presence = :available, address = nil)
      logger.debug "Returning #{agent} to the queue"

      return false unless get_agent(agent.id)

      agent.update_presence(new_presence)
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

    # Marks an agent as available to take a call.
    # @see #return_agent
    # @raises [ElectricSlide::CallQueue::MissingAgentError] when the agent cannot be returned because they have been explicitly removed.
    def return_agent!(*args)
      return_agent(*args) || abort(MissingAgentError.new('Agent is not in the queue. Unable to return agent.'))
    end

    # Removes an agent from the queue entirely
    # @param [Agent] agent The {Agent} to be removed from the queue
    # @param [Hash] extra_params Application specific extra params
    # @return [Agent, Nil] The Agent object if removed, Nil otherwise
    def remove_agent(agent, extra_params = {})
      agent.update_presence(:unavailable, extra_params)
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
      # In case this is a re-insert on agent failure...
      # ... reset `:agent` call variable
      call[:agent] = nil
      # ... set, but don't reset, the enqueue time
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
      unless queued_call && queued_call.active?
        logger.warn "Inactive queued call found in #connect"
        return_agent agent
        return
      end

      queued_call[:agent] = agent

      logger.info "Connecting #{agent} with #{remote_party queued_call}"
      case @connection_type
      when :call
        call_agent agent, queued_call
      when :bridge
        bridge_agent agent, queued_call
      end
    rescue *ENDED_CALL_EXCEPTIONS
      ignoring_ended_calls do
        if queued_call && queued_call.active?
          logger.warn "Dead call exception in #connect but queued_call still alive, reinserting into queue"
          priority_enqueue queued_call
        end
      end
      ignoring_ended_calls do
        if agent.call && agent.call.active?
          logger.warn "Dead call exception in #connect but agent call still alive, reinserting into queue"
          agent.callback :connection_failed, current_actor, agent.call, queued_call

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

      queue = current_actor

      # The call controller is actually run by #dial, here we skip joining if we do not have one
      dial_options = agent.dial_options_for(queue, queued_call)
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
      queued_call.register_tmp_handler :event, Adhearsion::Event::Joined do |event|
        connected = true
        queued_call[:electric_slide_connected_at] = event.timestamp
      end

      agent_call.on_end do |end_event|
        # Ensure we don't return an agent that was removed or paused
        conditionally_return_agent agent

        agent.call = nil

        agent.callback :disconnect, queue, agent_call, queued_call

        unless connected
          if queued_call.active?
            ignoring_ended_calls { priority_enqueue queued_call }
            agent.callback :connection_failed, queue, agent_call, queued_call

            logger.warn "Call did not connect to agent! Agent #{agent.id} call ended with #{end_event.reason}; reinserting caller #{queued_caller_id} into queue"
          else
            logger.warn "Caller #{queued_caller_id} hung up before being connected to an agent."
          end
        end
      end

      agent.callback :connect, queue, agent_call, queued_call

      agent_call.execute_controller_or_router_on_answer dial_options.delete(:confirm), dial_options.delete(:confirm_metadata)

      agent_call.dial agent.address, dial_options
    end

    def bridge_agent(agent, queued_call)
      unless agent.call && agent.call.active?
        logger.warn "Inactive agent call found for Agent #{agent.id} while bridging. Logging out agent and returning caller to queue."
        priority_enqueue queued_call
        remove_agent agent
        return
      end

      # Stash caller ID to make log messages work even if calls end
      queued_caller_id = remote_party queued_call
      agent.call[:queued_call] = queued_call

      queue = current_actor
      agent.call.register_tmp_handler :event, Adhearsion::Event::Unjoined do
        agent.callback :disconnect, queue, agent.call, queued_call
        ignoring_ended_calls { queued_call.hangup }
        ignoring_ended_calls { conditionally_return_agent agent if agent.call && agent.call.active? }
        agent.call[:queued_call] = nil if agent.call
      end

      queued_call.register_tmp_handler :event, Adhearsion::Event::Joined do |event|
        queued_call[:electric_slide_connected_at] = event.timestamp
      end

      agent.callback :connect, current_actor, agent.call, queued_call

      agent.join queued_call if queued_call.active?
    rescue *ENDED_CALL_EXCEPTIONS
      ignoring_ended_calls do
        if agent.call && agent.call.active?
          agent.callback :connection_failed, current_actor, agent.call, queued_call

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

    def accept_agent!(agent)
      case @connection_type
      when :call
        unless agent.callable?
          abort ArgumentError.new('Agent has no callable address')
        end
      when :bridge
        bridged_agent_health_check agent
      end
    end

    # @private
    def bridged_agent_health_check(agent)
      if agent.presence == :available && @connection_type == :bridge
        abort ArgumentError.new("Agent has no active call") unless agent.call && agent.call.active?
        unless agent.call[:electric_slide_callback_set]
          agent.call[:electric_slide_callback_set] = true
          queue = current_actor
          agent.call.on_end do
            agent.call = nil
            queue.return_agent agent, :unavailable
          end
        end
      end
    end
  end
end
