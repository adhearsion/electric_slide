require 'spec_helper'

describe ElectricSlide::QueueStrategy do
  include ElectricSlide::QueueStrategy

  describe '#wrap_call' do
    it 'should pass through a QueuedCall object' do
      obj = ElectricSlide::QueuedCall.new dummy_call
      wrap_call(obj).should be obj
    end

    it 'should wrap any object that does not respond to #queued_time' do
      wrap_call(dummy_call).should be_a ElectricSlide::QueuedCall
    end
  end
end
