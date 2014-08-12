require 'spec_helper'

describe ElectricSlide do
  it "should default to an ElectricSlide::CallQueue if one is not specified" do
    ElectricSlide.create "test queue"
    expect { ElectricSlide.get_queue("test queue") }.to_not raise_error
    ElectricSlide.shutdown_queue "test queue"
  end

  it "should raise if attempting to work with a queue that doesn't exist" do
    expect { ElectricSlide.get_queue("does not exist!") }.to raise_error
    expect { ElectricSlide.shutdown_queue("does not exist!") }.to raise_error
  end

  it "should preserve a queue object that is passed in" do
    ElectricSlide.create :foo, :bar
    expect(ElectricSlide.get_queue(:foo)).to be :bar
  end

end
