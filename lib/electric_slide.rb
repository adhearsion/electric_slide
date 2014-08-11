# encoding: utf-8
require 'singleton'

class ElectricSlide < Adhearsion::Plugin
  include Singleton

  def initialize
    @mutex = Mutex.new
    @queues = {}
  end

  def create(name, queue = nil)
    queue ||= CallQueue.supervise name

    if @queues.key?(name)
      fail "Queue with name #{name} already exists!"
    else
      @queues[name] = queue
    end
  end

  def get_queue(name)
    fail "Queue #{name} not found!" unless @queues[name]
    @queues[name]
  end

private

  def shutdown_queue(name)
    queue = get_queue name
    queue.shutdown!
    @queues.delete queue
  end

  def self.method_missing(method, *args, &block)
    @@mutex ||= Mutex.new
    @@mutex.synchronize do
      instance.send method, *args, &block
    end
  end
end
