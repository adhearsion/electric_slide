# encoding: utf-8
require 'spec_helper'

describe ElectricSlide::CallQueue do
  let(:queue) { ElectricSlide::CallQueue.new }
  let(:call_a) { dummy_call }
  let(:call_b) { dummy_call }
  let(:call_c) { dummy_call }

  describe ".agent_class" do

    class Foo; end

    class FooQueue <  ElectricSlide::CallQueue
      agent_class Foo
    end

    let(:foo_queue) { FooQueue }

    it "has a default class" do
      expect(ElectricSlide::CallQueue.agent_class).to eq ElectricSlide::Agent
    end

    it "can be changed" do
      FooQueue.agent_class Foo
      expect(FooQueue.agent_class).to eq Foo
    end

    describe "#agent_class" do
      it "gets it from the class variable" do
        expect(queue.agent_class).to eq ElectricSlide::Agent
        expect(foo_queue.new.agent_class).to eq Foo
      end
    end
  end

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

  it "should select the agent that has been waiting the longest"

end
