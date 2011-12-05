class ElectricSlide
  class RoundRobinMeetme
    include QueueStrategy

    def initialize(call)
      @queue = []
    end

    def next_call
      call = synchronize do
        @queue.pop
      end

      call.make_ready!
      call
    end

    def priority_enqueue(call)
      call = wrap_call(call)

      synchronize do
        @queue.unshift call
      end
      super
    end

    def enqueue(call)
      synchronize do
        @queue << call
      end
    end
  end
end

