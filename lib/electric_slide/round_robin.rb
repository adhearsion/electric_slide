require 'thread'
require 'electric_slide/queue_strategy'

class ElectricSlide
  class RoundRobin
    include QueueStrategy
    attr_reader :queue, :conditional

    def initialize
      @queue = []
      @conditional = ConditionVariable.new
    end

    def next_call
      call = nil
      synchronize do
        @conditional.wait(@mutex) if @queue.length == 0
        call = @queue.shift
      end

      call.make_ready!
      call
    end

    # TODO: Add mechanism to add calls with higher priority to the front of the queue.

    def enqueue(call)
      call = wrap_call(call)
      synchronize do
        @queue << call
        @conditional.signal if @queue.length == 1
      end
      super
    end
  end
end

