require 'vertebra/deferrable'

module Vertebra
  class Synapse
    include Vertebra::Deferrable

    def [](key)
      (@_data ||= {})[key]
    end

    def []=(key, val)
      (@_data ||= {})[key] = val
    end

    def condition &block
      return unless block

      case @deferred_status
      when :succeeded, :failed
        SetCallbackFailed.new
      else
        @conditions ||= []
        @conditions.unshift block
      end
    end

    def conditions
      (@conditions ||= []) && @conditions
    end

    def deferred_status?(*args)
      r = :unk
      state = :succeed
      case @deferred_status
      when :succeeded, :failed
        r = @deferred_status
      else
        if @conditions
          @conditions.reverse_each do |cond|
            r = cond.call(self,*args)
            if r == true
              r = :succeeded
            elsif !r
              r = :failed
            end
            break if r == :failed or r == :deferred
          end
        else
          r = :succeeded
        end
      end
      r
    end

  end
end
