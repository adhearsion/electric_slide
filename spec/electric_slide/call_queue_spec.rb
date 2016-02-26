# encoding: utf-8
require 'spec_helper'
require 'electric_slide/agent_strategy/fixed_priority'

describe ElectricSlide::CallQueue do
  let(:queue) { ElectricSlide::CallQueue.new }

  context "enqueuing calls" do
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
      call_a << Punchblock::Event::End.new(reason: :hangup)
      expect(queue.get_next_caller).to be call_b
    end

    it "records the time in the :electric_slide_enqueued_at call variable on the queued call" do
      enqueue_time = DateTime.new(2015, 9, 30, 15, 0, 23)
      Timecop.freeze enqueue_time
      queue.enqueue call_a
      expect(call_a[:electric_slide_enqueued_at]).to eq(enqueue_time)
    end
  end

  it "should raise when given an invalid Agent" do
    expect { queue.add_agent nil }.to raise_error(ArgumentError)
  end

  describe 'connecting agents to callers' do
    let(:agent_return_method) { :auto }

    let(:queue) { ElectricSlide::CallQueue.new(connection_type: connection_type, agent_return_method: agent_return_method) }
    let(:agent_id) { '123' }
    let(:agent) { ElectricSlide::Agent.new id: agent_id, address: '123', presence: :available }
    let!(:agent_call) { Adhearsion::OutboundCall.new }
    let(:queued_call) { dummy_call }
    let(:connected_time) { DateTime.now }

    before do
      allow(Adhearsion::OutboundCall).to receive(:new) { agent_call }
      allow(agent).to receive(:dial_options_for) {
        { confirm: double('ConfirmController') }
      }

      allow(queued_call).to receive(:active?) { true }
    end

    context "with connection type :call" do
      let(:connection_type) { :call }

      before do
        allow(agent_call).to receive(:dial)
        queue.add_agent agent
        queue.enqueue queued_call
      end

      it "sets the agent's `call` attribute" do
        expect(agent.call).to be agent_call
      end

      it 'records the agent in the `:agent` call variable on the queued call' do
        expect(queued_call[:agent]).to eq(agent)
      end

      context 'when the call ends' do
        let(:double_agent) { double(ElectricSlide::Agent, presence: :available).as_null_object }

        before do
          # add another agent so that it gets selected after the
          # currently-selected agent's call ends; otherwise, the agent just
          # gets returned and is immediately connected to the queued call,
          # causing its state to change before the examples have a chance to
          # check it
          queue.add_agent double_agent
        end

        it "unsets the agent's `call` attribute" do
          expect {
            agent_call << Punchblock::Event::End.new(reason: :hangup)
          }.to change(agent, :call).from(agent_call).to(nil)
        end

        context "when the return strategy is :auto" do
          let(:agent_return_method) { :auto }

          it "makes the agent available for a call" do
            agent_call << Punchblock::Event::End.new(reason: :hangup)
            expect(queue.checkout_agent).to eql(agent)
          end

          it "sets the agent's presence to :available" do
            agent_call << Punchblock::Event::End.new(reason: :hangup)
            expect(queue.get_agent(agent.id).presence).to eql(:available)
          end
        end

        context "when the return strategy is :manual" do
          let(:agent_return_method) { :manual }

          it "does not make the agent available for a call" do
            agent_call << Punchblock::Event::End.new(reason: :hangup)
            expect(queue.checkout_agent).to eql(nil)
          end

          it "sets the agent's presence to :after_call" do
            agent_call << Punchblock::Event::End.new(reason: :hangup)
            expect(queue.get_agent(agent.id).presence).to eql(:after_call)
          end
        end

        context "when the agent's and caller's calls are not joined" do
          context 'and the call ends' do
            before do
              queue.remove_agent(double_agent)

              # prevent the agent from being returned to the queue so the queued
              # call isn't grabbed by the agent again, changing queued call state
              # before the example can check it
              agent.update_presence(:unavailable)
            end

            it 'unsets the `:agent` call variable on the queued call' do
              expect {
                agent_call << Punchblock::Event::End.new(reason: :hangup)
              }.to change{ queued_call[:agent] }.from(agent).to(nil)
            end
          end
        end

        context "with callbacks" do
          after do
            [:connect_callback, :disconnect_callback, :connection_failed_callback, :presence_change_callback].each do |callback|
              ElectricSlide::Agent.instance_variable_set "@#{callback}", nil
            end
          end

          it "invokes the presence change callback" do
            called = false
            ElectricSlide::Agent.on_presence_change { |queue, agent_call, presence| called = true }
            agent_call << Punchblock::Event::End.new(reason: :hangup)
            expect(called).to be true
          end
        end
      end

      context "when the agent's and caller's calls are joined" do
        before do
          queued_call << Punchblock::Event::Joined.new(timestamp: connected_time)
          agent_call << Punchblock::Event::Joined.new(timestamp: connected_time)
        end

        it "records the connection time in the :electric_slide_connected_at call variable on the queued call" do
          expect(queued_call[:electric_slide_connected_at]).to eq(connected_time)
        end
      end
    end

    context "with connection type :bridge" do
      let(:connection_type) { :bridge }

      before do
        allow(agent_call).to receive(:active?) { true }
        allow(queued_call).to receive(:hangup) { true }
        agent.call = agent_call
        queue.add_agent agent

        allow(agent_call).to receive(:join) do
          agent_call << Punchblock::Event::Joined.new(timestamp: connected_time)
          queued_call << Punchblock::Event::Joined.new(timestamp: connected_time)
        end
        queue.enqueue queued_call
      end

      it 'records the agent in the `:agent` call variable on the queued call' do
        expect(queued_call[:agent]).to eq(agent)
      end

      it "records the connection time in the :electric_slide_connected_at call variable on the queued call" do
        expect(queued_call[:electric_slide_connected_at]).to eq(connected_time)
      end

      context 'when the call ends' do
        it "unsets the agent's `call` attribute" do
          expect {
            agent_call << Punchblock::Event::End.new(reason: :hangup)
          }.to change(agent, :call).from(agent_call).to(nil)
        end

        it "marks the agent :unavailable" do
          expect {
            agent_call << Punchblock::Event::End.new(reason: :hangup)
          }.to change(agent, :presence).from(:on_call).to(:unavailable)
        end

        context "when the return strategy is :auto" do
          let(:agent_return_method) { :auto }

          it "makes the agent available for a call" do
            agent_call << Punchblock::Event::Unjoined.new
            expect(queue.checkout_agent).to eql(agent)
          end

          it "sets the agent's presence to :available" do
            agent_call << Punchblock::Event::Unjoined.new
            expect(queue.get_agent(agent.id).presence).to eql(:available)
          end
        end

        context "when the return strategy is :manual" do
          let(:agent_return_method) { :manual }

          it "does not make the agent available for a call" do
            agent_call << Punchblock::Event::Unjoined.new
            expect(queue.checkout_agent).to eql(nil)
          end

          it "sets the agent's presence to :after_call" do
            agent_call << Punchblock::Event::Unjoined.new
            expect(queue.get_agent(agent.id).presence).to eql(:after_call)
          end
        end
      end
    end
  end

  describe '#add_agent' do
    let(:queue) { ElectricSlide::CallQueue.new }
    let(:agent) { ElectricSlide::Agent.new(id: '1', address: 'agent@example.com') }

    before do
      allow(agent).to receive(:call) { Adhearsion::OutboundCall.new }
    end

    it "associates the agent with in the queue" do
      expect {
        queue.add_agent agent
      }.to change(queue, :get_agents).from([]).to([agent])
    end

    it "makes the agent available to take calls" do
      expect {
        queue.add_agent agent
      }.to change(queue, :checkout_agent).from(nil).to(agent)
    end

    it "connects the agent to waiting queued calls" do
      call = Adhearsion::OutboundCall.new
      queue.enqueue call

      queue.add_agent agent
      sleep 0.5
      expect(agent.presence).to eq(:on_call)
      expect(call[:agent]).to eq(agent)
    end

    context 'when given an agent already in the queue' do
      before do
        queue.add_agent(agent)
      end

      it 'should raise an error' do
        expect{
          queue.add_agent(agent)
        }.to raise_error(ElectricSlide::CallQueue::DuplicateAgentError)
      end
    end
  end

  describe '#update_agent' do
    let(:queue) { ElectricSlide::CallQueue.new(connection_type: :call) }
    let(:agent) { ElectricSlide::Agent.new(id: '1', address: 'agent@example.com', presence: :on_call) }

    before do
      queue.add_agent(agent)
    end

    it 'updates the agent with the given attributes' do
      expect {
        queue.update_agent(agent, address: 'reagent@acme.com')
      }.to change(agent, :address).from('agent@example.com').to('reagent@acme.com')
    end

    it 'returns the agent to the queue' do
      expect(queue.wrapped_object).to receive(:return_agent).with(agent, :on_call)
      queue.update_agent(agent, address: 'reagent@acme.com')
    end

    context 'when given a set of attributes that makes the agent unacceptable in the queue' do
      it 'raises an error' do
        expect {
          queue.update_agent(agent, address: '')
        }.to raise_error(ArgumentError, 'Agent has no callable address')
      end

      it "does not change the agent's attributes" do
        expect { queue.update_agent(agent, address: '') }.to raise_error(ArgumentError)

        expect(agent.id).to eq('1')
        expect(agent.address).to eq('agent@example.com')
        expect(agent.presence).to eq(:on_call)
      end
    end

    context 'when given an agent not in the queue' do
      before do
        queue.remove_agent agent
      end

      it 'raises an error' do
        expect {
          queue.update_agent(agent, address: 'ghost@imf.com')
        }.to raise_error(ElectricSlide::CallQueue::MissingAgentError, 'Agent is not in the queue')
      end
    end
  end

  describe '#return_agent' do
    let(:queue) { ElectricSlide::CallQueue.new }
    let(:agent) { ElectricSlide::Agent.new(id: '1', address: 'agent@example.com', presence: :on_call) }

    before do
      allow(agent).to receive(:call) { Adhearsion::OutboundCall.new }
    end

    context 'when the agent is a member of the queue' do
      before do
        queue.add_agent agent
      end

      it "sets the agent presence available" do
        expect {
          queue.return_agent agent
        }.to change(agent, :presence).from(:on_call).to(:available)
      end

      it "makes the agent available to take calls" do
        expect {
          queue.return_agent agent
        }.to change(queue, :checkout_agent).from(nil).to(agent)
      end

      context "when returned with some presence other than available" do
        it "reflects that status on the agent" do
          expect {
            queue.return_agent agent, :after_call
          }.to change(agent, :presence).from(:on_call).to(:after_call)
        end

        it "does not make the agent available to take calls" do
          expect {
            queue.return_agent agent, :after_call
          }.to_not change { queue.checkout_agent }
        end
      end
    end

    context 'when given an agent not in the queue' do
      it 'should cleanly return false' do
        expect(queue.return_agent(agent)).to be(false)
      end

      context 'when called with a bang' do
        it 'should raise an error' do
          expect{
            queue.return_agent!(agent)
          }.to raise_error(ElectricSlide::CallQueue::MissingAgentError)
        end
      end
    end
  end

  describe '#remove_agent' do
    let(:queue) { ElectricSlide::CallQueue.new }
    let(:agent) { ElectricSlide::Agent.new(id: '1', address: 'agent@example.com', presence: :available) }

    before do
      queue.add_agent agent
    end

    it 'sets the agent presence to `:unavailable`' do
      expect {
        queue.remove_agent agent
      }.to change(agent, :presence).from(:available).to(:unavailable)
    end

    it 'invokes the presence change callback' do
      called = false
      ElectricSlide::Agent.on_presence_change { |queue, agent_call, presence| called = true }
      queue.remove_agent agent
      expect(called).to be_truthy
    end

    it 'takes the agent out of the call rotation' do
      expect {
        queue.remove_agent agent
      }.to change(queue, :checkout_agent).from(agent).to(nil)
    end

    it 'removes the agent from the queue' do
      queue.remove_agent agent
      expect(queue.get_agents).to_not include(agent)
    end
  end

  describe '#update' do
    let(:queue) {
      ElectricSlide::CallQueue.new(
        agent_strategy: ElectricSlide::AgentStrategy::LongestIdle,
        connection_type: :call,
        agent_return_method: :auto
      )
    }

    it 'updates all the given attributes' do
      queue.update(
        agent_strategy: ElectricSlide::AgentStrategy::FixedPriority,
        connection_type: :bridge,
        agent_return_method: :manual
      )
      expect(queue.agent_strategy).to eq(ElectricSlide::AgentStrategy::FixedPriority)
      expect(queue.connection_type).to eq(:bridge)
      expect(queue.agent_return_method).to eq(:manual)
    end

    context 'when given an unrecognized attribute' do
      it 'does not raise an error' do
        expect{
          queue.update(foo: :bar)
        }.to_not raise_exception
      end
    end

    context 'when given `nil`' do
      it 'does not raise an error' do
        expect{
          queue.update(foo: :bar)
        }.to_not raise_exception
      end
    end
  end

  describe '#agent_strategy=' do
    let(:queue) {
      ElectricSlide::CallQueue.new(
        agent_strategy: ElectricSlide::AgentStrategy::LongestIdle,
        connection_type: :call,
        agent_return_method: :auto
      )
    }

    it 'returns the given strategy class' do
      expect(queue.agent_strategy = ElectricSlide::AgentStrategy::FixedPriority).to eq(ElectricSlide::AgentStrategy::FixedPriority)
    end

    it 'assigns a new strategy' do
      expect(ElectricSlide::AgentStrategy::FixedPriority).to receive(:new)
      queue.agent_strategy = ElectricSlide::AgentStrategy::FixedPriority
    end

    it 'returns all agents to the queue (strategy)' do
      agent = double(ElectricSlide::Agent, address: '100', presence: :available, priority: 100).as_null_object
      queue.add_agent(agent)

      queue.agent_strategy = ElectricSlide::AgentStrategy::FixedPriority
      expect(queue.available_agent_summary).to eq({ total: 1, priorities: { 100 => 1 }})
    end
  end

  describe '#connection_type=' do
    context 'when given an invalid connection type' do
      it 'raises an `InvalidConnectionType` exception' do
        expect{
          queue.connection_type = :party_line
        }.to raise_exception(ElectricSlide::CallQueue::InvalidConnectionType)
      end
    end
  end

  describe '#agent_return_method=' do
    context 'when given an invalid agent return method' do
      it 'raises an `InvalidRequeueMethod` exception' do
        expect{
          queue.agent_return_method = :semiauto
        }.to raise_exception(ElectricSlide::CallQueue::InvalidRequeueMethod)
      end
    end
  end
end
