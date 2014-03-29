# encoding: utf-8

class ElectricSlide
  class QueuedCall
    attr_reader :call, :wait_time

    def initialize(queue, call)
      return self if call.is_a? self.class

      @queue, @call = queue, call
      @call.auto_hangup = false
      @wait_time = Time.now
    end
  end
end

