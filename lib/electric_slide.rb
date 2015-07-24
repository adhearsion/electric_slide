# encoding: utf-8
require 'celluloid'
require 'singleton'

require 'adhearsion/version'

if Gem::Version.new(Adhearsion::VERSION) < Gem::Version.new('3.0.0')
  # Backport https://github.com/adhearsion/adhearsion/commit/8c6855612c70dd822fb4e4c2006d1fdc9d05fe23 to avoid confusion around dead calls
  require 'adhearsion/call'
  class Adhearsion::Call::ActorProxy < Celluloid::ActorProxy
    def active?
      alive? && super
    rescue Adhearsion::Call::ExpiredError
      false
    end
  end
end

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

  def create(name, queue_class = nil, *args)
    fail "Queue with name #{name} already exists!" if @queues.key? name

    queue_class ||= CallQueue
    @queues[name] = queue_class.work *args
    # Return the queue instance or current actor
    get_queue name
  end

  def get_queue!(name)
    fail "Queue #{name} not found!" unless @queues.key?(name)
    get_queue name
  end

  def get_queue(name)
    queue = @queues[name]
    if queue.respond_to? :actors
      # In case we have a Celluloid supervision group, get the current actor
      queue.actors.first
    else
      queue
    end
  end

  def shutdown_queue(name)
    queue = get_queue name
    queue.terminate
    @queues.delete name
  end

  def self.method_missing(method, *args, &block)
    @@mutex ||= Mutex.new
    @@mutex.synchronize do
      instance.send method, *args, &block
    end
  end
end
