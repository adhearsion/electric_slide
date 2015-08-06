# encoding: utf-8
require 'spec_helper'

describe ElectricSlide::CallQueue do
  let(:queue) { ElectricSlide::CallQueue.new }
  let(:call_a) { dummy_call }
  let(:call_b) { dummy_call }
  let(:call_c) { dummy_call }
  before :each do
    queue.enqueue call_a
    queue.enqueue call_b
    queue.enqueue call_c
  end

  it "should return callers in the same order they were enqueued" do
    expect(queue.get_next_caller).to be call_a
    expect(queue.get_next_caller).to be call_b
    expect(queue.get_next_caller).to be call_c
  end

  it "should return a priority caller ahead of the queue" do
    call_d = dummy_call
    queue.priority_enqueue call_d
    expect(queue.get_next_caller).to be call_d
    expect(queue.get_next_caller).to be call_a
  end

  it "should remove a caller who abandons the queue" do
    queue.enqueue call_a
    queue.enqueue call_b
    queue.abandon call_a
    expect(queue.get_next_caller).to be call_b
  end

  it "should raise when given an invalid connection type" do
    expect { ElectricSlide::CallQueue.new connection_type: :blah }.to raise_error
  end

  it "should raise when given an invalid Agent" do
    expect { queue.add_agent nil }.to raise_error
  end

  describe '#call_agent' do
    let(:queue) { ElectricSlide::CallQueue.new(connection_type: :call) }
    let(:agent) { ElectricSlide::Agent.new }
    let!(:agent_call) { Adhearsion::OutboundCall.new }

    before do
      allow(Adhearsion::OutboundCall).to receive(:new) { agent_call }
      allow(agent).to receive(:dial_options_for) {
        { confirm: double('ConfirmController') }
      }

      allow(call_a).to receive(:active?) { true }
      allow(agent_call).to receive(:dial)
      queue.connect(agent, call_a)
    end

    it "sets the agent's `call` attribute" do
      expect(agent.call).to be agent_call
    end

    context 'when the call ends' do
      it "unsets the agent's `call` attribute" do
        expect {
          agent_call << Punchblock::Event::End.new(reason: :hangup)
        }.to change(agent, :call).from(agent_call).to(nil)
      end
    end
  end
end
