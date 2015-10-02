# encoding: utf-8
require 'celluloid'

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
  agent
  call_queue
  plugin
).each { |f| require "electric_slide/#{f}" }

class ElectricSlide
  class Supervisor < Celluloid::SupervisionGroup
    def [](name)
      @registry[name]
    end
  end

  @supervisor = Supervisor.run!(Celluloid::Registry.new)

  def self.create(name, queue_class = nil, *args)
    fail "Queue with name #{name} already exists!" if get_queue(name)
    @supervisor.supervise_as name, (queue_class || CallQueue), *args
    get_queue name
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
