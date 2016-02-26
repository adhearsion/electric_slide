# encoding: utf-8
require 'spec_helper'
require 'electric_slide/agent'

describe ElectricSlide::Agent do
  let(:options) { { id: 1, address: '123@foo.com', presence: :available} }

  class MyAgent < ElectricSlide::Agent
    on_connect { foo }
    on_connection_failed { foo }
    on_disconnect { foo }
    on_presence_change { foo }

    def foo
      :bar
    end
  end

  subject {MyAgent.new options}

  after do
    [:connect_callback, :disconnect_callback, :connection_failed_callback, :presence_change_callback].each do |callback|
      ElectricSlide::Agent.instance_variable_set "@#{callback}", nil
    end
  end

  it 'executes a connect callback' do
    expect(subject.callback(:connect)).to eql :bar
  end

  it 'executes a disconnect callback' do
    expect(subject.callback(:disconnect)).to eql :bar
  end

  it 'executes a connection failed callback' do
    expect(subject.callback(:connection_failed)).to eql :bar
  end

  it 'executes a presence change callback' do
    expect(subject.callback(:presence_change, nil, nil, nil, nil)).to eql :bar
  end

  it 'executes the presence change callback on state change' do
    called = false
    ElectricSlide::Agent.on_presence_change { |queue, agent_call, presence| called = true }
    agent = ElectricSlide::Agent.new presence: :unavailable
    agent.update_presence(:busy)

    expect(called).to be_truthy
  end

  it 'sends `extra_params` and `old_presence` to the presence change callback' do
    presence_change_attributes = []
    ElectricSlide::Agent.on_presence_change do |*attrs|
      presence_change_attributes = attrs
    end

    agent = ElectricSlide::Agent.new presence: :unavailable
    agent.update_presence(:busy, triggered_by: 'auto')

    queue, agent_call, presence, old_presence, extra_params = presence_change_attributes

    expect(old_presence).to eq :unavailable
    expect(extra_params[:triggered_by]).to eq 'auto'
  end

  describe '#update' do
    it 'returns the agent' do
      expect(subject.update).to eq(subject)
    end

    context 'when given a hash with an agent attribute as key' do
      it "sets the corresponding agent's attribute to the given value" do
        expect {
          subject.update(address: '456@bar.net')
        }.to change(subject, :address).from('123@foo.com').to('456@bar.net')
      end
    end

    context 'when given an non-hash argument' do
      it 'raises an error' do
        expect {
          subject.update(nil)
        }.to raise_error(ArgumentError, 'Agent attributes must be a hash')
      end
    end

    context 'when given a hash with a key that does not correspond to any agent attribute' do
      it "raises an error" do
        expect {
          subject.update(blah: 1)
        }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#callable?' do
    context 'when the agent has an address' do
      before do
        subject.address = 'Baker St.'
      end

      it 'returns `true`' do
        expect(subject).to be_callable
      end
    end

    context 'when the agent has no address' do
      before do
        subject.address = ''
      end

      it 'returns `false`' do
        expect(subject).to_not be_callable
      end
    end
  end
end
