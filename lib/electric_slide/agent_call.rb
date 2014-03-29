# encoding: utf-8

class ElectricSlide
  class AgentCall
    attr_reader :call, :wait_time

    def initialize(queue, call)
      return self if call.is_a? self.class
      @queue, @call = queue, call
      @queued_time = Time.now

      call.auto_hangup = false

      setup_callbacks
    end

    def setup_callbacks
      @call.on_unjoined do
        # Should fire whenever the caller disconnects from the agent
        wait_for_call if call.active?
      end

      @call.on_end do
        logout
      end
    end

    def wait_for_call
      @queue.add_agent @call
    end


    def logout
      @queue.remove_agent @call
    end

    class << self
      def waiting_for_call(&block)
        @waiting_for_call = block
      end

    end
  end
end


