# encoding: utf-8

require 'spec_helper'
require 'electric_slide/agent_strategy/fixed_priority'
require 'ostruct'

describe ElectricSlide::AgentStrategy::FixedPriority do
  let(:subject) { ElectricSlide::AgentStrategy::FixedPriority.new }
  it 'should allow adding an agent with a specified priority' do
    subject.agent_available?.should be false
    subject << OpenStruct.new({ id: 101, priority: 1 })
    subject.agent_available?.should be true
  end

  it 'should allow adding multiple agents at the same priority' do
    agent1 = OpenStruct.new({ id: 101, priority: 2 })
    agent2 = OpenStruct.new({ id: 102, priority: 2 })
    subject << agent1
    subject << agent2
    subject.checkout_agent.should == agent1
  end

  it 'should return all agents of a higher priority before returning an agent of a lower priority' do
    agent1 = OpenStruct.new({ id: 101, priority: 2 })
    agent2 = OpenStruct.new({ id: 102, priority: 2 })
    agent3 = OpenStruct.new({ id: 103, priority: 3 })
    subject << agent1
    subject << agent2
    subject << agent3
    subject.checkout_agent.should == agent1
    subject.checkout_agent.should == agent2
    subject.checkout_agent.should == agent3
  end

  it 'should detect an agent available if one is available at any priority' do
    agent1 = OpenStruct.new({ id: 101, priority: 2 })
    agent2 = OpenStruct.new({ id: 102, priority: 3 })
    subject << agent1
    subject << agent2
    subject.checkout_agent
    subject.agent_available?.should == true
  end
end
