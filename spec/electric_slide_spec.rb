require 'spec_helper'

describe ElectricSlide do
  it "should default to an ElectricSlide::CallQueue if one is not specified" do
    ElectricSlide.create "test queue"
    ElectricSlide.get_queue("test queue").class.should be ElectricSlide::CallQueue
  end

end
