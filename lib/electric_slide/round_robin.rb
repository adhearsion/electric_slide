require 'thread'
require 'electric_slide/queue_strategy'

class ElectricSlide
  class RoundRobin
    include QueueStrategy
    attr_reader :queue

    def initialize
      @queue = []
      @agents_waiting = []
      @conditional = ConditionVariable.new
    end

    def next_call
      call = nil
      synchronize do
        @agents_waiting << Thread.current
        @conditional.wait(@mutex) if @queue.length == 0
        @agents_waiting.delete Thread.current
        call = @queue.shift
      end

      call.make_ready!
      call
    end

    def agents_waiting
      synchronize do
        @agents_waiting.dup
      end
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

