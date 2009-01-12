require 'vertebra/deferrable'

module Vertebra
	class Synapse
		include Vertebra::Deferrable

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
				r = [nil, @deferred_status]
			else
				if @conditions
					@conditions.each do |cond|
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
