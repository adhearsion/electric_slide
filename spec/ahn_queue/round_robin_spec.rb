require 'spec_helper'
#require File.join(File.dirname(__FILE__), '..', 'spec_helper')

#class AhnQueue
#  describe RoundRobin do

describe AhnQueue::RoundRobin do
  before :each do
    @queue = AhnQueue::RoundRobin.new
    @call  = AhnQueue::QueuedCall.new dummy_call
    flexmock(@call).should_receive(:hold).once
  end

  describe "Queue is empty at start" do
    pending
    # subject { AhnQueue::RoundRobin.new }
    # its(:queue) {should have(0).items }
  end

  it 'should properly enqueue a call' do
    @queue.enqueue @call
    @queue.instance_variable_get(:@queue).first.should be @call
  end

  it 'should return the call object that is passed in' do
    @queue.enqueue @call
    flexmock(@call).should_receive(:make_ready!).once
    @queue.next_call.should be @call
  end

  it 'should block an agent requesting a call until a call becomes available' do
    flexmock(@call).should_receive(:make_ready!).once
    agent_thread = Thread.new { @queue.next_call }

    # Give the agent thread a chance to block...
    sleep 0.5

    condvar = @queue.instance_variable_get(:@conditional)
    waiters = condvar.instance_variable_get(:@waiters)
    waiters.count.should == 1

    @queue.enqueue @call

    # Give the agent thread a chance to retrieve the call...
    sleep 0.5
    waiters.count.should == 0
    agent_thread.kill
  end

  it 'should unblock only one agent per call entering the queue' do
    agent1_thread = Thread.new { @queue.next_call }
    agent2_thread = Thread.new { @queue.next_call }

    # Give the agent threads a chance to block...
    sleep 0.5

    condvar = @queue.instance_variable_get(:@conditional)
    waiters = condvar.instance_variable_get(:@waiters)
    waiters.count.should == 2

    flexmock(@call).should_receive(:make_ready!).once
    @queue.enqueue @call

    # Give the agent thread a chance to retrieve the call...
    sleep 0.5
    waiters.count.should == 1
    agent1_thread.kill
    agent2_thread.kill
  end
end
