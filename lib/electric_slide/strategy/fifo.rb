# encoding: utf-8

class ElectricSlide
  class Strategy
    class Fifo
      def initialize
        @queue = []
      end

      def add(call)
        @queue.push call
      end
      
      def next_call
        @queue.shift
      end

      def remove(call)
        @queue.delete call
      end

      def count
        @queue.length
      end
    end
  end
end

