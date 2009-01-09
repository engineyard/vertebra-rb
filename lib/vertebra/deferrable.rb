# This deferrable implementation is based upon the Deferrable found in
# EventMachine.  It is modified to work with the GLib event loop, and
# the functionality is slightly altered from the original. Refer to the
# EventMachine distribution for the original implementation.

require 'forwardable'

module Vertebra
	module Deferrable

    class CallbackFailed < Exception
    end
    
    TimeoutStatus = {}
    
  	def callback &block
  		return unless block

  		if @deferred_status == :succeeded
  			block.call(*@args)
  		elsif @deferred_status != :failed
  			@callbacks ||= []
  			@callbacks.unshift block
  		else
  			CallbackFailed.new
  		end
  	end

  	def errback &block
  		return unless block

  		if @deferred_status == :failed
  			block.call(*@deferred_args)
  		elsif @deferred_status != :succeeded
  			@errbacks ||= []
  			@errbacks.unshift block
 			else
  			CallbackFailed.new
  		end
  	end

    def callbacks
      (@callbacks ||= []) && @callbacks
    end
    
    def errbacks
      (@errbacks ||= []) && @errbacks
    end
    
  	def set_deferred_status status, *args
      r = nil
  		cancel_timeout

  		@deferred_status = status
  		@deferred_args = args

  		case @deferred_status
  		when :succeeded
  			if @callbacks
  				while cb = @callbacks.pop
  					r = cb.call(*@deferred_args)
  				end
  			end
  			@errbacks.clear if @errbacks
  		when :failed
  			if @errbacks
  				while eb = @errbacks.pop
  					r = eb.call(*@deferred_args)
  				end
  			end
  			@callbacks.clear if @callbacks
  		end
  		r
  	end

  	def timeout seconds
  		cancel_timeout
  		me = self
  		@deferred_timeout = GLib::Timeout.add((seconds*1000).to_i) {me.fail}
  	end

  	def cancel_timeout
  		if @deferred_timeout
  			GLib::Source.remove(@deferred_timeout)
  			@deferred_timeout = nil
  		end
  	end

  	def set_deferred_success *args
  		set_deferred_status :succeeded, *args
  	end

  	def set_deferred_failure *args
  		set_deferred_status :failed, *args
  	end

  	def succeed *args
  		set_deferred_success(*args)
  	end

  	def fail *args
  		set_deferred_failure(*args)
  	end
  	
  	# Vertebra::Deferrable::Klass can be used as a default deferrable.
  	class Klass
      include Vertebra::Deferrable
  	end
  end

  # Vertebra::DeferrableClass can be used as a default deferrable.
  class DeferrableClass
  	include Deferrable
  end
  

end

