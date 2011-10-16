require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe AhnQueue::QueueStrategy do
  include AhnQueue::QueueStrategy

  describe '#wrap_call' do
    it 'should pass through a QueuedCall object' do
      obj = AhnQueue::QueuedCall.new dummy_call
      wrap_call(obj).should be obj
    end

    it 'should wrap any object that does not respond to #queued_time' do
      wrap_call(dummy_call).should be_a AhnQueue::QueuedCall
    end
  end
end
