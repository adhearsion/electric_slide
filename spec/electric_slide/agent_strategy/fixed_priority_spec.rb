# encoding: utf-8

require 'spec_helper'
require 'electric_slide/agent_strategy/fixed_priority'
require 'ostruct'

describe ElectricSlide::AgentStrategy::FixedPriority do
  it 'should allow adding an agent with a specified priority' do
    expect(subject.agent_available?).to be false
    subject << OpenStruct.new({ id: 101, priority: 1 })
    expect(subject.agent_available?).to be true
  end

  it 'should allow adding multiple agents at the same priority' do
    agent1 = OpenStruct.new({ id: 101, priority: 2 })
    agent2 = OpenStruct.new({ id: 102, priority: 2 })
    subject << agent1
    subject << agent2
    expect(subject.checkout_agent).to eql(agent1)
  end

  it 'should return all agents of a higher priority before returning an agent of a lower priority' do
    agent1 = OpenStruct.new({ id: 101, priority: 2 })
    agent2 = OpenStruct.new({ id: 102, priority: 2 })
    agent3 = OpenStruct.new({ id: 103, priority: 3 })
    subject << agent3
    subject << agent1
    subject << agent2
    expect(subject.checkout_agent).to eql(agent1)
    expect(subject.checkout_agent).to eql(agent2)
    expect(subject.checkout_agent).to eql(agent3)
  end

  it 'should detect an agent available if one is available at any priority' do
    agent1 = OpenStruct.new({ id: 101, priority: 2 })
    agent2 = OpenStruct.new({ id: 102, priority: 3 })
    subject << agent1
    subject << agent2
    subject.checkout_agent
    expect(subject.agent_available?).to be true
  end

  context 'when agents at different priorities are available' do
    let(:agent1) { agent1 = OpenStruct.new(id: 101, priority: 1) }
    let(:agent2) { agent1 = OpenStruct.new(id: 102, priority: 2) }

    before do
      subject << agent1
      subject << agent2
    end

    describe 'and the higher priority agent is added again, but at the lowest priority' do
      before do
        agent1.priority = 3
        subject << agent1
      end

      it 'moves the agent to the new, lower priority' do
        expect(subject.checkout_agent).to eq(agent2)
      end
    end
  end
end
