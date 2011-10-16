require 'singleton'
require 'adhearsion/foundation/thread_safety'

#methods_for :dialplan do
#end
#
#initialization do
#  COMPONENTS.ahn_queue[:queues].each do |q|
#    AhnQueue.create q[:name], q[:queue_type], q[:agent_type]
#  end
#end

class AhnQueue
  include ::Singleton

  def initialize
    @queues = {}
  end

  def create(name, queue_type, agent_type = Agent)
    synchronize do
      @queues[name] = const_get(queue_type).new unless @queues.has_key?(name)
      @queues[name].extend agent_type
    end
  end

  def get_queue(name)
    synchronize do
      @queues[name]
    end
  end

  def self.method_missing(method, *args, &block)
    instance.send method, *args, &block
  end

#  module Agent
#    def work(agent_call)
#      loop do
#        agent_call.execute 'Bridge', @queue.next_call
#      end
#    end
#  end
#
#  class CalloutAgent
#    def work(agent_channel)
#      @queue.next_call.each do |next_call|
#        next_call.dial agent_channel
#      end
#    end
#  end
#
#  class MeetMeAgent
#    include Agent
#
#    def work(agent_call)
#      loop do
#        agent_call.join agent_conf, @queue.next_call
#      end
#    end
#  end
#
#  class BridgeAgent
#    include Agent
#  end
end
