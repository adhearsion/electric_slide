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

  it "should select the agent that has been waiting the longest"

  it "should raise when given an invalid connection type" do
    expect { ElectricSlide::CallQueue.new :blah }.to raise_error
  end
end
