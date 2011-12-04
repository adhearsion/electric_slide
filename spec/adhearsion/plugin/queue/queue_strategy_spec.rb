require 'spec_helper'

describe Adhearsion::Plugin::Queue::QueueStrategy do
  include Adhearsion::Plugin::Queue::QueueStrategy

  describe '#wrap_call' do
    it 'should pass through a QueuedCall object' do
      obj = Adhearsion::Plugin::Queue::QueuedCall.new dummy_call
      wrap_call(obj).should be obj
    end

    it 'should wrap any object that does not respond to #queued_time' do
      wrap_call(dummy_call).should be_a Adhearsion::Plugin::Queue::QueuedCall
    end
  end
end
