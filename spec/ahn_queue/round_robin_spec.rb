require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe AhnQueue::RoundRobin do
  before :each do
    @queue = AhnQueue::RoundRobin.new
    @call  = AhnQueue::QueuedCall.new dummy_call
  end

  it 'should properly enqueue a call' do
    flexmock(@call).should_receive(:hold).once
    @queue.enqueue @call
    @queue.instance_variable_get(:@queue).first.should be @call
  end
end
