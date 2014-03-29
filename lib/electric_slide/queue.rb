# encoding: utf-8

class ElectricSlide
  class Queue
    include Celluloid

    class << self
      def name(name)
        @name = name
      end

      def queue_strategy(strategy)
        klass = if strategy.respond_to :new
          # We have been passed a class to instantiate
          strategy
        elsif strategy.is_a? Symbol
          # Look up the class within the ElectricSlide::Strategy namespace
          klass_name = strategy.to_s.camelcase
          ElectricSlide::Strategy.const_get klass_name
        else
          raise ArgumentError
        end

        klass.new
      end

      def caller_strategy(strategy = nil)
        @caller_strategy ||= queue_strategy(strategy || :fifo)
      end

      def agent_strategy(strategy = nil)
        @agent_strategy ||= queue_strategy(strategy || :fifo)
      end

      def method_missing(m, *args, &block)
        # TODO: How to instantiate the supervised actor?
        Celluloid::Actor[self.class.underscore.to_sym].send m, *args, &block
      end
    end

    def to_s
      "#<ElectricSlide::Queue(#{self.class.name}) callers_waiting: #{@caller_strategy.count}; agents_waiting: #{@agent_strategy.count}>"
    end

    def wait_for_agent(caller)
      caller = QueuedCall.new caller
      caller_strategy.add caller
    end

    def work_queue(agent)
      agent = AgentCall.new agent
      @agent_strategy.add agent
    end
  end
end

