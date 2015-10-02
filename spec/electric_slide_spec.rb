require 'spec_helper'

describe ElectricSlide do
  context "creating a queue" do
    after :each do
      ElectricSlide.shutdown_queue :fake
    end

    it "should default to an ElectricSlide::CallQueue if one is not specified" do
      ElectricSlide.create :fake
      expect(ElectricSlide.get_queue :fake).to be_a(ElectricSlide::CallQueue)
    end

    it "should start the queue upon registration" do
      ElectricSlide.create :fake
      expect(ElectricSlide.get_queue(:fake).alive?).to be true
    end

    it "should start a custom queue type" do
      queue_class = Class.new(ElectricSlide::CallQueue)
      ElectricSlide.create :fake, queue_class
      expect(ElectricSlide.get_queue(:fake).alive?).to be true
    end

    it "should preserve additional queue arguments" do
      ElectricSlide.create :fake, nil, agent_return_method: :manual
      expect(ElectricSlide.get_queue(:fake).agent_return_method).to be(:manual)
    end

    it "should not allow a second queue to be created with the same name" do
      ElectricSlide.create :fake
      expect { ElectricSlide.create :fake }.to raise_error(StandardError)
    end
  end

  describe "shutting down a queue" do
    before do
      ElectricSlide.create :fooqueue
      ElectricSlide.shutdown_queue :fooqueue
    end

    it "should make the queue inaccessible" do
      expect(ElectricSlide.get_queue(:fooqueue)).to be_nil
    end

    context "more than once" do
      it "should remain silent" do
        expect {
          ElectricSlide.shutdown_queue :fooqueue
          ElectricSlide.shutdown_queue :fooqueue
        }.not_to raise_error
      end
    end
  end
end
