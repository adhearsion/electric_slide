# encoding: utf-8
require 'countdownlatch'

class ElectricSlide
  class QueuedCall
    attr_accessor :call, :queued_time

    def initialize(call)
      @call = call
      @queued_time = Time.now
    end

    def lock
      @hangup_latch = CountDownLatch.new 1
      @hangup_latch.wait
    end

    def free!
      @hangup_latch.countdown!
    end

    def hold
      initiate_moh
      @latch = CountDownLatch.new 1
      @latch.wait
      suspend_moh
    end

    def make_ready!
      @latch.countdown!
    end

    def initiate_moh
      # TODO: Make MOH configurable
      @call.execute_controller do
        moh_handle = play! moh_audio
        metadata[:moh_handle] = moh_handle
      end
    end

    def suspend_moh
      @call.controllers.each do |controller|
        if controller.metadata[:moh_handle]
          controller.metadata[:moh_handle].stop!
        end
      end
    end
  end
end

