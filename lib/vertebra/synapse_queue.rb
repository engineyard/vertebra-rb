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

    def fire(show_synapses = false)
      endpoint = @queue.length - 1
      
      logger.debug "QUEUE: iterating from 0..#{endpoint}" if show_synapses
      @queue[0..endpoint].each do |synapse|
        next unless synapse && synapse.respond_to?(:deferred_status?)
        ds = synapse.deferred_status?
        logger.debug "QUEUE: ds: #{ds}" if show_synapses
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
