require 'countdownlatch'

class AhnAcd
  module QueueStrategy
    def wrap_call(call)
      QueuedCall.new(call) unless call.respond_to?(:queued_time)
    end

    def priority_enqueue(call)
      enqueue call
    end

    def enqueue(call)
      call.hold
    end
  end
end
