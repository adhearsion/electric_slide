require 'countdownlatch'

class AhnQueue
  module QueueStrategy
    def wrap_call(call)
      call = QueuedCall.new(call) unless call.respond_to?(:queued_time)
      call
    end

    def priority_enqueue(call)
      # TODO: Add this call to the front of the line
      enqueue call
    end

    def enqueue(call)
      call.hold
    end
  end
end
