require 'spec_helper'

describe AhnQueue::QueuedCall do
  it 'should initialize the queued_time to the current time' do
    now = Time.now
    flexmock(Time).should_receive(:now).once.and_return now
    qcall = AhnQueue::QueuedCall.new dummy_call
    qcall.instance_variable_get(:@queued_time).should == now
  end

  it 'should start and stop music on hold when put on hold and released' do
    # Both tests are combined here so we do not leave too many suspended threads lying about
    queued_caller = dummy_call
    flexmock(queued_caller).should_receive(:execute).once.with('StartMusicOnHold')
    flexmock(queued_caller).should_receive(:execute).once.with('StopMusicOnHold')
    qcall = AhnQueue::QueuedCall.new queued_caller

    # Place the call on hold and wait for it to enqueue
    Thread.new { qcall.hold }
    sleep 0.5

    # Release the call from being on hold and sleep to ensure we get the Stop MOH signal
    qcall.make_ready!
    sleep 0.5
  end

  it 'should block the call when put on hold' do
    queued_caller = dummy_call
    flexmock(queued_caller).should_receive(:execute).once.with('StartMusicOnHold')
    flexmock(queued_caller).should_receive(:execute).once.with('StopMusicOnHold')
    qcall = AhnQueue::QueuedCall.new queued_caller

    hold_thread = Thread.new { qcall.hold }

    # Give the holding thread a chance to block...
    sleep 0.5
    hold_thread.status.should == "sleep"
    qcall.make_ready!
    sleep 0.5
    hold_thread.status.should be false
  end
end
