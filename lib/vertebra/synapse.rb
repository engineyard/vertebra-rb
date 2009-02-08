# Copyright 2008, Engine Yard, Inc.
#
# This file is part of Vertebra.
#
# Vertebra is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Vertebra is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Vertebra.  If not, see <http://www.gnu.org/licenses/>.

# This file is a reimplementation of xmpp4r's rexmladdons. As such, it depends
# on some parts of REXML.

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
