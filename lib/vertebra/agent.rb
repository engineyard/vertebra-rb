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

require 'vertebra/dispatcher'
require 'vertebra/actor'
#require 'vertebra/helpers/pubsub'
require 'vertebra/synapse'

begin
#require 'ruby-growl'
rescue LoadError
	logger.debug "Install the growl gem for growl support. Growl notifications disabled."
end

module Vertebra
	class Agent

		include Vertebra::Daemon

		attr_accessor :drb_port
		attr_reader :jid
		
		attr_accessor :dispatcher, :herault_jid, :clients, :servers
		attr_reader :ttl

		BUSY_CHECK_INTERVAL = 0.1

		def initialize(jid, password, opts = {})
			Vertebra.config = @opts = opts

			raise(ArgumentError, "Please provide at least a Jabber ID and password") if !jid || !password

			Vertebra::Daemon.setup_pidfile unless @opts[:background]

			@drb_port = @opts[:drb_port]

			#Jabber.debug = @opts[:jabber_debug] || false

			add_include_path(@opts[:actor_path]) if @opts[:actor_path]
			add_include_path(File.dirname(__FILE__) + "/../../spec/mocks") if @opts[:test_mode]

			@jid = Vertebra::JID.new(jid)
			@jid.resource ||= 'agent'
			@password = password

			@busy_jids = {}
			@pending_clients = []
			@active_clients = []
			@connection_in_progress = false
			@authentication_in_progress = false
			@synapse_queue = []
			
			@advertise_timer_started = false
			@herault_jid = opts[:herault_jid] || 'herault@localhost/herault'
			@ttl = opts[:ttl] || 3600 # Default TTL for advertised resources is 3600 seconds.
			
			@main_loop = GLib::MainLoop.new(nil,nil)
			@conn = LM::Connection.new
			@conn.jid = @jid.to_s

			install_signal_handlers
			install_periodic_actions
			
			# TODO: Add options for these intervals, instead of a hardcoded timing?


			set_callbacks

			@dispatcher = ::Vertebra::Dispatcher.new(self, opts[:default_resources])

			@clients, @servers = {},{}

			# register actors specified in the config
			@dispatcher.register(opts[:actors]) if opts[:actors]
		end

		def install_signal_handlers
			trap('SIGINT') {@main_loop.quit}
			trap('SIGTERM') {@main_loop.quit}
			trap('SIGUSR1') {GC.start; File.open('/tmp/objdump','w+') {|fh| ObjectSpace.each_object {|o| fh.puts "#{o} -- #{o.inspect}"}}; GC.start}
		end
		
		def install_periodic_actions
			GLib::Timeout.add(2) { fire_synapses; true }
			GLib::Timeout.add(1000) { clear_busy_jids; true }
			GLib::Timeout.add(2000) { monitor_connection_status; true }
			GLib::Timeout.add(801) { GC.start; true}
			GLib::Timeout.add(1) { connect; false } # Try to connect immediately after startup.			
			GLib::Timeout.add(1000) { advertise_resources; false } # run once, a second after startup.
		end
		
    # Is this layer necessary?
    def client
      @conn
    end

    def clear_queues
      # I don't think there's any reason for this, anymore.
    end
    
		def enqueue_synapse(synapse)
			@synapse_queue << synapse
		end

		def fire_synapses
			new_synapse_queue = []
			@synapse_queue.each do |synapse|
        next unless synapse && synapse.respond_to?(:deferred_status?) # Defend against somehow getting a non-synapse in here.
				ds = synapse.deferred_status?
				case ds
				when :succeeded
					synapse.set_deferred_status(:succeeded)
				when :failed
					synapse.set_deferred_status(:failed)
				else
					new_synapse_queue << synapse
				end
			end
			
			@synapse_queue = new_synapse_queue
		end

		def monitor_connection_status
			unless @connection_in_progress
				# Check to see if the connection is open and authenticated.  Try to deal
				# with it if it is not.
				if !@conn.open?
					connect
				elsif !@authentication_in_progress && !@conn.authenticated?
					offer_authentication
				end
			end
		end
		
		def connect
			opener = Vertebra::Synapse.new
			opener.callback do
				unless @conn.open?
					logger.debug "opening connection"
					success = @conn.open {} # TODO: Loudmouth-Ruby should be fixed so this empty block isn't necessary
				
					if success
						offer_authentication
					else
						@connection_in_progress = false
						logger.debug "open failed"
					end
				end
			end
			enqueue_synapse(opener)
		end
		
		def connection_exists_and_is_open?
      @conn && @conn.open? ? true : :deferred
		end
		
		def connection_is_open_and_authenticated?
      connection_exists_and_is_open? && @conn.authenticated? ? true : :deferred
		end
		
		def offer_authentication
			authenticator = Vertebra::Synapse.new
			authenticator.timeout = 10
			authenticator.condition { connection_exists_and_is_open? }
			authenticator.callback do
				unless @conn.authenticated?
					logger.debug "authenticating"
					success = @conn.authenticate(@jid.node, @password, "agent") {}
					if success
						finalize_authentication
					else
						logger.debug "Failure while presenting authentication"
					end
					@connection_in_progress = @authentication_in_progress = false
				end
			end
			authenticator.errback do
				logger.debug "Authentication timed out"
			end
			enqueue_synapse(authenticator)
		end
		
		def finalize_authentication
			auth_finalizer = Vertebra::Synapse.new
			auth_finalizer.condition { connection_is_open_and_authenticated? }
			auth_finalizer.callback do
				# If any other post_authentication steps are required, this is where
				# to place them.
				logger.debug "Authenticated"
			end
			enqueue_synapse(auth_finalizer)
		end
		
		def defer_on_busy_jid?(jid)
			@busy_jids.has_key?(jid) ? :deferred : :succeeded
		end

		def set_busy_jid(jid,client)
			@busy_jids[jid] = client
		end
		
		def remove_busy_jid(jid)
			@busy_jids.delete(jid)
		end

		def clear_busy_jids
			# Busy jids _should_ be cleared by the protocol, but just in case, a
			# timer will run this periodically to catch anything that might somehow
			# be missed.  TODO: Prove this is unnecessary paranoia.
			
			@busy_jids.each do |jid, client|
				@busy_jids.delete(jid) if client.done?
			end
		end

		def set_callbacks
			@conn.set_disconnect_handler do |reason|
				logger.debug "Disconnected -- #{reason}"
				reconnector = Vertebra::Synapse.new
				# Immediately try to reconnect on a disconnect.
				reconnector.callback {connect}
				enqueue_synapse(reconnector)
			end

			@conn.add_message_handler(LM::MessageType::IQ) do |iq|
				logger.debug "GOT IQ #{iq.node.class}"
				handle_iq(iq)
			end    
		end

		def start
			begin
				DRb.start_service("druby://127.0.0.1:#{@drb_port}", self) if @opts[:use_drb]
			rescue Errno::EADDRINUSE
				logger.warn "An agent is already running on DRb port #{@drb_port}."
				exit!
			else
				logger.info "Starting DRb on port #{@drb_port}" if @opts[:use_drb]
			end
			
			@main_loop.run
		end

		def direct_op(op_type, to, *args)
			op = Vertebra::Op.new(op_type, *args)
			client = Vertebra::Protocol::Client.new(self, op, to)
			logger.debug("#direct_op #{op_type} #{to} #{args.inspect} for #{self}")
			client
		end

		def op(op_type, to, *args)
# The old op() model doesn't work in an evented architecture, since it is blocking.
# TODO: Figure out if we need to simulate it somehow (i.e. fake fibers with threads
# to make it look blocking) or if direct_op() is sufficient.
		end

		# #discover takes as args a list of resources either in string form
		# (/foo/bar) or as instances of Vertebra::Resource.  It returns a list
		# of jids that will handle any of the resources.
#		def discover(*resources)
#			logger.debug "DISCOVERING: #{resources.inspect} on #{@herault_jid}"
#			op('/security/discover', @herault_jid, *resources.collect {|r| Vertebra::Resource === r ? r.to_s : r})
#		end

		def request(op_type, *raw_args)
			# If the scope of the request is going to be specified, it should be
			# passed via a symbol as the first arg -- :single or :all.  That arg
			# will be removed from the list before issuing the request.  If a
			# scope is not given, :all is the assumed scope.
			
			case raw_args.first
			when :single
				scope = :single
				raw_args.shift
			when :all
				scope = :all
				raw_args.shift
			else
				scope = :all
			end
			
			resources = raw_args.select {|r| Vertebra::Resource === r}
			cooked_args = []
			specific_jids = []
			raw_args.each do |arg|
				next if Vertebra::Resource === arg
				
				if arg =~ /^jid:(.*)/
					specific_jids << $1
				else
					cooked_args << arg
				end
			end
			jids = discover(op_type,*resources)
			if Array === jids
				target_jids = jids.concat(specific_jids)
			else
				target_jids = jids['jids'].concat(specific_jids)
			end
			
			if scope == :all
				gather(scatter(target_jids, op_type, *cooked_args))
			else
				gather_first(scatter(target_jids, op_type, *cooked_args))
			end
		end


		def scatter(jids, op_type, *args)
			ops = {}
			jids.each do |jid|
				logger.debug "scatter# #{op_type}/#{jid}/#{args.inspect}"
				ops[jid] = direct_op(op_type, jid, *args)
			end
			ops
		end

		def single_scatter_and_gather(jids, op_type, *args)
			errors = [:error]
			result = nil
			jids.each do |jid|
				op = direct_op(op_type, jid, *args)
				until client.done?
					sleep(0.1)
				end
				if client.state == :commit # A completion
					result = client.results
					break
				elsif client.state == :error
					errors << client.results
				end
			end
			
			result ? result : errors
		end

		def gather(ops={})
			results = []
			while ops.size > 0 do
				ops.each do |jid, client|
					logger.debug "#{jid} -- #{client.state}"
					if client.done?
						results << client.results unless client.results.empty?
						ops.delete(jid)
					end
				end
				sleep(1)
			end
			results
		end

		def handle_iq(iq)
			logger.debug "handle_iq: #{iq.node}"
      unhandled = true
      
			if op = iq.node.get_child('op')
        if op['token'].size == 32
          # The protocol object will take care of enqueing itself.
          Vertebra::Protocol::Server.new(self,iq)
        else
          # TODO: Should we do anything if the op has a token of incorrect
          # length?  Some sort of error response?
        end
			end
			
			if unhandled && ack = iq.node.get_child('ack')
        client = @clients[ack.get_attribute('token')]
        if client
          ack_handler = Vertebra::Synapse.new
          ack_handler[:client] = client
          ack_handler[:state] = :ack
          ack_handler.callback {logger.debug "ack"; client.process_ack_or_nack(iq, :ack, ack)}
        end
        enqueue_synapse(ack_handler)
        unhandled = false 
			end

      if unhandled && nack = iq.node.get_child('nack')
        client = @clients[ack.get_attribute('token')]
        if client
          nack_handler = Vertebra::Synapse.new
          nack_handler[:client] = client
          nack_handler[:state] = :nack
          nack_handler.callback {logger.debug "nack"; client.process_ack_or_nack(iq, :nack, nack)}
        end
        enqueue_synapse(nack_handler)
        unhandled = false
      end

			if unhandled && result = iq.node.get_child('result')
        client = @clients[result.get_attribute('token')]
        if client
          result_handler = Vertebra::Synapse.new
          result_handler[:client] = client
          result_handler[:state] = :result
          result_handler.callback {logger.debug "result"; client.process_result_or_final(iq, :result, result)}
        end
        enqueue_synapse(result_handler)
        unhandled = false 
			end

      if unhandled && final = iq.node.get_child('final')
        client = @clients[final.get_attribute('token')]
        if client
          final_handler = Vertebra::Synapse.new
          final_handler[:client] = client
          final_handler[:state] = :final
          final_handler.callback {logger.debug "final"; client.process_result_or_final(iq, :final, final)}
        end
        enqueue_synapse(final_handler)
        unhandled = false
      end
      
      if unhandled
				logger.debug "#{iq.node} getting dropped, unhandled"
      end
		end

		def advertise_op(resources, ttl = @ttl)
			logger.debug "ADVERTISING: #{resources.inspect}"
			direct_op('/security/advertise', @herault_jid, :resources => resources, :ttl => ttl)
			logger.debug "  DONE ADVERTISING"
		end

		def unadvertise_op(resources)
			logger.debug "UNADVERTISING: #{resources.inspect}"
			direct_op('/security/advertise', @herault_jid, :resources => resources, :ttl => 0)
		end

		def advertise_resources
			advertise_op(provided_resources)
			unless @advertise_timer_started
				GLib::Timeout.add_seconds(@ttl * 0.9) {advertise_op(provided_resources,@ttl)} 
				@advertise_timer_started = true
			end
		end

		def provided_resources
			actors = @dispatcher.actors || []
			actors.collect {|actor| actor.provides }.flatten
		end

		def self.default_status
			(File.exists?("/proc") ? File.read("/proc/loadavg") : `uptime`.split(":").last).gsub("\n", '')
		end
		
		private
		
		def add_include_path(path)
			$:.unshift path
		end
	end
end
