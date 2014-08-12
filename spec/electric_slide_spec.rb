require 'spec_helper'

describe ElectricSlide do
  it "should default to an ElectricSlide::CallQueue if one is not specified" do
    ElectricSlide.create "test queue"
    expect { ElectricSlide.get_queue("test queue") }.to_not raise_error
    ElectricSlide.shutdown_queue "test queue"
  end

  it "should start the queue upon registration" do
    queue = double(:fake_queue)
    expect(queue).to receive(:work)
    ElectricSlide.create :fake, queue
  end

  it "should raise if attempting to work with a queue that doesn't exist" do
    expect { ElectricSlide.get_queue("does not exist!") }.to raise_error
    expect { ElectricSlide.shutdown_queue("does not exist!") }.to raise_error
  end

end
