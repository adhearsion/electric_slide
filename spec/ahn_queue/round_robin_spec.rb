require 'spec_helper'
#require File.join(File.dirname(__FILE__), '..', 'spec_helper')

#class AhnQueue
#  describe RoundRobin do

describe AhnQueue::RoundRobin do
  def dummy_queued_call
    dqc = AhnQueue::QueuedCall.new dummy_call
    flexmock(dqc).should_receive(:hold).once
    flexmock(dqc).should_receive(:make_ready!).once
    dqc
  end

  before :each do
    @queue = AhnQueue::RoundRobin.new
  end

  describe "Queue is empty at start" do
    pending
    # subject { AhnQueue::RoundRobin.new }
    # its(:queue) {should have(0).items }
  end

  it 'should properly enqueue a call' do
    call = AhnQueue::QueuedCall.new dummy_call
    flexmock(call).should_receive(:hold).once
    @queue.enqueue call
    @queue.instance_variable_get(:@queue).first.should be call
  end

  it 'should return the call object that is passed in' do
    call = dummy_queued_call
    @queue.enqueue call
    @queue.next_call.should be call
  end

  it 'should block an agent requesting a call until a call becomes available' do
    call = dummy_queued_call
    agent_thread = Thread.new { @queue.next_call }

    # Give the agent thread a chance to block...
    sleep 0.5

    condvar = @queue.instance_variable_get(:@conditional)
    waiters = condvar.instance_variable_get(:@waiters)
    waiters.count.should == 1

    @queue.enqueue call

    # Give the agent thread a chance to retrieve the call...
    sleep 0.5
    waiters.count.should == 0
    agent_thread.kill
  end

  it 'should unblock only one agent per call entering the queue' do
    call = dummy_queued_call
    agent1_thread = Thread.new { @queue.next_call }
    agent2_thread = Thread.new { @queue.next_call }

    # Give the agent threads a chance to block...
    sleep 0.5

    condvar = @queue.instance_variable_get(:@conditional)
    waiters = condvar.instance_variable_get(:@waiters)
    waiters.count.should == 2

    @queue.enqueue call

    # Give the agent thread a chance to retrieve the call...
    sleep 0.5
    waiters.count.should == 1
    agent1_thread.kill
    agent2_thread.kill
  end

  it 'should properly enqueue calls and return them in the same order' do
    call1 = dummy_queued_call
    call2 = dummy_queued_call
    call3 = dummy_queued_call
    threads = {}

    threads[:call1] = Thread.new { @queue.enqueue call1 }
    sleep 0.5
    threads[:call2] = Thread.new { @queue.enqueue call2 }
    sleep 0.5
    threads[:call3] = Thread.new { @queue.enqueue call3 }
    sleep 0.5


    @queue.next_call.should be call1
    @queue.next_call.should be call2
    @queue.next_call.should be call3
  end
end
