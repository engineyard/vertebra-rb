module Vertebra
  class SynapseQueue
    def initialize
      @queue = []
    end

    def << (synapse)
      @queue << synapse
    end

    def clear
      @queue = []
    end

    def fire
      endpoint = @queue.length - 1
      
      @queue[0..endpoint].each do |synapse|
        next unless synapse && synapse.respond_to?(:deferred_status?)
        ds = synapse.deferred_status?
        case ds
        when :succeeded
          synapse.set_deferred_status(:succeeded,synapse)
        when :failed
          synapse.set_deferred_status(:failed,synapse)
        else
          @queue << synapse
        end
      end

      @queue = (@queue.length > (endpoint + 1)) ? @queue[(endpoint + 1)..-1] : []
    end

    def first
      @queue.first
    end

    def size
      @queue.size
    end
  end
end
