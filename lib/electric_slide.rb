# encoding: utf-8
require 'celluloid'

require 'adhearsion/version'

if Gem::Version.new(Adhearsion::VERSION) < Gem::Version.new('3.0.0')
  # Backport https://github.com/adhearsion/adhearsion/commit/8c6855612c70dd822fb4e4c2006d1fdc9d05fe23 to avoid confusion around dead calls
  require 'adhearsion/call'
  class Adhearsion::Call
    class ActorProxy
      def active?
        alive? && super
      rescue ExpiredError
        false
      end
    end
  end
end

%w(
  agent
  call_queue
  plugin
).each { |f| require "electric_slide/#{f}" }

class ElectricSlide
  class Supervisor < Celluloid::SupervisionGroup
    def [](name)
      @registry[name]
    end

    def names
      @registry.names
    end
  end

  @supervisor = Supervisor.run!(Celluloid::Registry.new)

  def self.queues_by_name
    @supervisor.names.inject({}) do |queues, name|
      queues[name] = get_queue(name)
      queues
    end
  end

  def self.create(name, queue_class = nil, *args)
    fail "Queue with name #{name} already exists!" if get_queue(name)

    queue_class ||= CallQueue
    if !queue_class.respond_to?(:valid_with?) || queue_class.valid_with?(*args)
      @supervisor.supervise_as name, (queue_class || CallQueue), args: args
      get_queue name
    end
  end

  def self.get_queue!(name)
    get_queue(name) || fail("Queue #{name} not found!")
  end

  def self.get_queue(name)
    @supervisor[name]
  end

  def self.shutdown_queue(name)
    queue = get_queue name
    queue.terminate if queue
  end
end
