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
      new_queue = []
      @queue.each do |synapse|
        # Defend against somehow getting a non-synapse in here.
        next unless synapse && synapse.respond_to?(:deferred_status?)
        ds = synapse.deferred_status?
        case ds
        when :succeeded
          synapse.set_deferred_status(:succeeded,synapse)
        when :failed
          synapse.set_deferred_status(:failed,synapse)
        else
          new_queue << synapse
        end
      end

      @queue = new_queue
    end

    def first
      @queue.first
    end

    def size
      @queue.size
    end
  end
end
