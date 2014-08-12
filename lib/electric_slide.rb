# encoding: utf-8
require 'celluloid'
require 'singleton'
%w(
  call_queue
  plugin
).each { |f| require "electric_slide/#{f}" }

class ElectricSlide
  include Singleton

  def initialize
    @mutex = Mutex.new
    @queues = {}
  end

  def create(name, queue = nil)
    queue ||= CallQueue.supervise

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

  def shutdown_queue(name)
    queue = get_queue name
    queue.terminate
    @queues.delete queue
  end

  def self.method_missing(method, *args, &block)
    @@mutex ||= Mutex.new
    @@mutex.synchronize do
      instance.send method, *args, &block
    end
  end
end
