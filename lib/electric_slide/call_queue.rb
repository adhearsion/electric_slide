# encoding: utf-8

# The default agent strategy
require 'electric_slide/agent_strategy/longest_idle'

class ElectricSlide
  class CallQueue
    include Celluloid

    CONNECTION_TYPES = [
      :call,
      :bridge,
    ].freeze

    def self.work(*args)
      self.supervise *args
    end

    def initialize(opts = {})
      agent_strategy   = opts[:agent_strategy]  || AgentStrategy::LongestIdle
      @connection_type = opts[:connection_type] || :call

      raise ArgumentError, "Invalid connection type; must be one of #{CONNECTION_TYPES.join ','}" unless CONNECTION_TYPES.include? @connection_type

      @free_agents = [] # Needed to keep track of waiting order
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

    # Assigns the first available agent, marking the agent :busy
    # @return {Agent}
    def checkout_agent
      agent = @strategy.checkout_agent
      agent.presence = :busy
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
    def add_agent(agent)
      case @connection_type
      when :call
        abort ArgumentError, "Agent has no callable address" unless agent.address
      when :bridge
        abort ArgumentError, "Agent has no active call" unless agent.call && agent.call.active?
      end

      logger.info "Adding agent #{agent} to the queue"
      @agents << agent unless @agents.include? agent
      @strategy << agent if agent.presence == :available
      check_for_connections
    end

    # Marks an agent as available to take a call. To be called after an agent completes a call
    # and is ready to take the next call.
    # @param [Agent] agent The {Agent} that is being returned to the queue
    # @param [Symbol] status The {Agent}'s new status
    # @param [String, Optional] address The {Agent}'s address. Only specified if it has changed
    def return_agent(agent, status = :available, address = nil)
      logger.debug "Returning #{agent} to the queue"
      agent.presence = status
      agent.address = address if address

      if agent.presence == :available
        @strategy << agent
        check_for_connections
      end
      agent
    end

    # Removes an agent from the queue entirely
    # @param [Agent] agent The {Agent} to be removed from the queue
    # @return [Agent, Nil] The Agent object if removed, Nil otherwise
    def remove_agent(agent)
      logger.info "Removing agent #{agent} from the queue"
      @strategy.delete agent
      @agents.delete agent
    end

    # Checks to see if any callers are waiting for an agent and attempts to connect them to
    # an available agent
    def check_for_connections
      while call_waiting? && agent_available?
        call = get_next_caller
        begin
          next unless call.active?
        rescue Adhearsion::Call::ExpiredError
          next
        end
        connect checkout_agent, call
        break
      end
    end

    # Add a call to the head of the queue. Among other reasons, this is used when a caller is sent
    # to an agent, but the connection fails because the agent is not available.
    # @param [Adhearsion::Call] call Caller to be added to the queue
    def priority_enqueue(call)
      # Don't reset the enqueue time in case this is a re-insert on agent failure
      call[:enqueue_time] ||= Time.now
      @queue.unshift call

      check_for_connections
    end

    # Add a call to the end of the queue, the normal FIFO queue behavior
    # @param [Adhearsion::Call] call Caller to be added to the queue
    def enqueue(call)
      logger.info "Adding call from #{call.from} to the queue"
      call[:enqueue_time] = Time.now
      @queue << call unless @queue.include? call

      check_for_connections
    end

    # Remove a waiting call from the queue. Used if the caller hangs up or is otherwise removed.
    # @param [Adhearsion::Call] call Caller to be removed from the queue
    def abandon(call)
      logger.info "Caller #{call.from} has abandoned the queue"
      @queue.delete call
    end

    # Connect an {Agent} to a caller
    # @param [Agent] agent Agent to be connected
    # @param [Adhearsion::Call] call Caller to be connected
    def connect(agent, queued_call)
      logger.info "Connecting #{agent} with #{queued_call.from}"
      case @connection_type
      when :call
        call_agent agent, queued_call
      when :bridge
        bridge_agent agent, queued_call
      end
    end

    def conditionally_return_agent(agent)
      if agent && @agents.include?(agent) && agent.presence == :busy
        logger.info "Returning agent #{agent.id} to queue"
        return_agent agent
      else
        logger.debug "Not returning agent #{agent.inspect} to the queue"
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
    # @private
    def ignoring_ended_calls
      yield
    rescue Celluloid::DeadActorError, Adhearsion::Call::Hangup, Adhearsion::Call::ExpiredError
      # This actor may previously have been shut down due to the call ending
    end

    def call_agent(agent, queued_call)
      agent_call = Adhearsion::OutboundCall.new
      agent_call[:agent]  = agent
      agent_call[:queued_call] = queued_call

      # Stash the caller ID so we don't have to try to get it from a dead call object later
      queued_caller_id = queued_call.from

      # The call controller is actually run by #dial, here we skip joining if we do not have one
      dial_options = agent.dial_options_for(self, queued_call)
      unless dial_options[:confirm]
        agent_call.on_answer { ignoring_ended_calls { agent_call.join queued_call.uri } }
      end

      # Disconnect agent if caller hangs up before agent answers
      queued_call.on_end { ignoring_ended_calls { agent_call.hangup } }

      agent_call.on_unjoined do
       ignoring_ended_calls { agent_call.hangup }
       ignoring_ended_calls { queued_call.hangup }
      end

      # Track whether the agent actually talks to the queued_call
      connected = false
      queued_call.on_joined { connected = true }

      agent_call.on_end do |end_event|
        # Ensure we don't return an agent that was removed or paused
        conditionally_return_agent agent

        agent.callback :disconnect, self, agent_call, queued_call

        unless connected
          if queued_call.alive? && queued_call.active?
            ignoring_ended_calls { priority_enqueue queued_call }
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
      queued_caller_id = queued_call.from

      agent.call.on_unjoined do
        agent.callback :disconnect, self, agent.call, queued_call
        ignoring_ended_calls { queued_call.hangup }
        ignoring_ended_calls { conditionally_return_agent agent if agent.call.active? }
      end

      agent.call.on_end do
        remove_agent agent
      end

      agent.call.on_joined do 
        agent.callback :connect, self, agent.call, queued_call
      end

      agent.join queued_call
    rescue Celluloid::DeadActorError, Adhearsion::Call::Hangup, Adhearsion::Call::ExpiredError
      ignoring_ended_calls do
        if agent.call.active?
          logger.info "Caller #{queued_caller_id} failed to connect to Agent #{agent.id} due to caller hangup"
          conditionally_return_agent agent
        end
      end

      ignoring_ended_calls do
        if queued_call.active?
          priority_enqueue queued_call
          logger.warn "Call failed to connect to Agent #{agent.id} due to agent hangup; reinserting caller #{queued_caller_id} into queue"
        end
      end
    end
  end
end
