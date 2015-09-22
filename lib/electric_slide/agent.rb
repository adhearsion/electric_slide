# encoding: utf-8

class ElectricSlide
  class Agent
    attr_accessor :id, :address, :presence, :call, :connect_callback, :disconnect_callback, :connection_failed_callback, :presence_callback

    # @param [Hash] opts Agent parameters
    # @option opts [String] :id The Agent's ID
    # @option opts [String] :address The Agent's contact address
    # @option opts [Symbol] :presence The Agent's current presence. Must be one of :available, :on_call, :after_call, :unavailable
    def initialize(opts = {})
      @id = opts[:id]
      @address = opts[:address]
      @presence = opts[:presence] || :available
    end

    def callback(type, *args)
      callback = self.class.instance_variable_get "@#{type}_callback"
      instance_exec *args, &callback if callback && callback.respond_to?(:call)
    end

    # Provide a block to be called when this agent is connected to a caller
    # The block will be passed the queue, the agent call and the client call
    def self.on_connect(&block)
      @connect_callback = block
    end

    # Provide a block to be called when this agent is disconnected to a caller
    # The block will be passed the queue, the agent call and the client call
    def self.on_disconnect(&block)
      @disconnect_callback = block
    end

    # Provide a block to be called when this agent's presence changes
    # The block will be passed the queue, the agent call, and the new presence
    def self.on_presence_change(&block)
      @presence_callback = block
    end

    # Provide a block to be called when the agent connection to the callee fails
    # The block will be passed the queue, the agent call and the client call
    def self.on_connection_failed(&block)
      @connection_failed_callback = block
    end

    def on_call?
      @presence == :on_call
    end

    # Called to provide options for calling this agent that are passed to #dial
    def dial_options_for(queue, queued_call)
      {}
    end

    def join(queued_call)
      # For use in queues that need bridge connections
      @call.join queued_call
    end

    # FIXME: Use delegator?
    def from
      @call.from
    end
  end
end
