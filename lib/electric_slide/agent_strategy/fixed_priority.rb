# encoding: utf-8

class ElectricSlide
  class AgentStrategy
    class FixedPriority
      def initialize
        @priorities = {}
      end

      def agent_available?
        !!@priorities.detect do |priority, agents|
          agents.present?
        end
      end

      def checkout_agent
        _, agents = @priorities.detect do |priority, agents|
          agents.present?
        end
        agents.shift
      end

      def <<(agent)
        # TODO: How aggressively do we check for agents duplicated in multiple priorities?
        raise ArgumentError, "Agents must have a specified priority" unless agent.respond_to?(:priority)
        priority = agent.priority
        @priorities[priority] ||= []
        @priorities[priority] << agent unless @priorities[priority].include? agent
      end

      def delete(agent)
        @priorities.detect do |priority, agents|
          agents.delete(agent)
        end
      end
    end
  end
end

