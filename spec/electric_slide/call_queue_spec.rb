# encoding: utf-8
require 'spec_helper'

describe ElectricSlide::CallQueue do
  let(:queue) { ElectricSlide::CallQueue.new }
  let(:call_a) { dummy_call }
  let(:call_b) { dummy_call }
  let(:call_c) { dummy_call }

  describe ".queue_name" do
    it "works as a supervised actor with a name" do
      expect(ElectricSlide::CallQueue.work).to eq Celluloid::Actor['call queue']
    end

    context "when given a different name" do
      after { ElectricSlide::CallQueue.queue_name 'call queue' }

      it "works as a different actor if given a different name" do
        ElectricSlide::CallQueue.queue_name :other_queue
        expect(ElectricSlide::CallQueue.work).to eq Celluloid::Actor[:other_queue]
      end
    end
  end

  describe "#.enqueue" do
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
  end

  it "should select the agent that has been waiting the longest"
end
