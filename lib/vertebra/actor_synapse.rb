module Vertebra
  class ActorSynapse < Synapse

    def initialize(agent)
      @agent = agent
      super()
    end

    def action(*args, &block)
      condition do
        begin
          error = nil
          result = block.call(self, *args)
        rescue Exception => e
          error = e
        end

        if Vertebra::Synapse === result
          # The action returned a deferrable, so it'll queue the deferrable
          result.set_deferred_status = nil
          @agent.enqueue_synapse(result)
          :deferred
        else
          self[:results] = result unless error
          self[:error] = error if error
          :succeeded
        end
      end

    end
  end
end
