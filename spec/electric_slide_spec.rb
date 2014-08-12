require 'spec_helper'

describe ElectricSlide do
  context "creating a queue" do
    after :each do
      ElectricSlide.shutdown_queue :fake
    end

    let(:queue_class) { double :fake_queue_class }
    let(:queue_inst)  { double :fake_queue_instance }

    it "should default to an ElectricSlide::CallQueue if one is not specified" do
      ElectricSlide.create :fake
      expect { ElectricSlide.get_queue :fake }.to_not raise_error
    end

    it "should start the queue upon registration" do
      expect(queue_class).to receive(:work).once.and_return queue_inst
      expect(queue_inst).to receive(:terminate).once
      ElectricSlide.create :fake, queue_class
    end

    it "should preserve additional queue arguments" do
      queue = double(:fake_queue)
      expect(queue_class).to receive(:work).with(:foo, :bar, :baz).once.and_return queue_inst
      expect(queue_inst).to receive(:terminate).once
      ElectricSlide.create :fake, queue_class, :foo, :bar, :baz
    end

    it "should not allow a second queue to be created with the same name" do
      ElectricSlide.create :fake
      expect { ElectricSlide.create :fake }.to raise_error
    end
  end

  it "should raise if attempting to work with a queue that doesn't exist" do
    expect { ElectricSlide.get_queue("does not exist!") }.to raise_error
    expect { ElectricSlide.shutdown_queue("does not exist!") }.to raise_error
  end

end
