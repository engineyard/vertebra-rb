require 'vertebra/deferrable'

module Vertebra
	class Synapse
		include Vertebra::Deferrable

		def condition &block
			return unless block

			case @deferred_status
			when :succeed, :fail
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
			state = :succeed
			case @deferred_status
			when :succeed, :fail
				nil
			else
				if @conditions
					while cond = @conditions.pop
						r = cond.call(self,*args)
						break if r == :failed or r == :deferred
					end
				end
			end
			r
		end
		
	end
end
