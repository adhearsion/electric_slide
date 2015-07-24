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

      # Returns information about the number of available agents
      # The data returned depends on the AgentStrategy in use.
      # @return [Hash] Summary information about agents available, depending on strategy
      # :total: The total number of available agents
      # :priorities: A Hash containing the number of available agents at each priority
      def available_agent_summary
        @priorities.inject({}) do |summary, data|
          priority, agents = *data
          summary[:total] ||= 0
          summary[:total] += agents.count
          summary[:priorities] ||= {}
          summary[:priorities][priority] = agents.count
          summary
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
        priority = agent.priority || 999999
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

