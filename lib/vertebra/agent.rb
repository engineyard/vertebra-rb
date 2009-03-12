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
require 'vertebra/sous_chef'
require 'vertebra/synapse'
require 'vertebra/synapse_queue'

begin
  #require 'ruby-growl'
rescue LoadError
  logger.debug "Install the growl gem for growl support. Growl notifications disabled."
end

module LmDispatcher
  def notify_readable
    notification = LM::Sink.notification
    notification.target.call(notification.data) if notification.target
  end
end

module Vertebra
  class Agent

    SLOW_TIMER_FREQUENCY = 50.0
    FAST_TIMER_FREQUENCY = 5.0
    
    include Vertebra::Daemon

    attr_accessor :drb_port
    attr_reader :jid

    attr_accessor :dispatcher, :herault_jid, :clients, :servers, :conn, :deja_vu_map
    attr_reader :ttl

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
      @deja_vu_map = Hash.new {|h1,k1| h1[k1] = {} }
      @synapse_queue = Vertebra::SynapseQueue.new

      @advertise_timer_started = false
      @herault_jid = opts[:herault_jid] || 'herault@localhost/herault'
      @ttl = opts[:ttl] || 3600 # Default TTL for advertised resources is 3600 seconds.

      @conn = LM::EventedConnection.new
      @conn.jid = @jid.to_s

      install_signal_handlers

      # TODO: Add options for these intervals, instead of a hardcoded timing?


      set_callbacks

      @dispatcher = ::Vertebra::Dispatcher.new(self, opts[:default_resources])

      @clients, @servers = {},{}

      @show_synapses = false

      # register actors specified in the config
      @dispatcher.register(opts[:actors]) if opts[:actors]
    end

    def stop
      EM.stop
    end

    def install_signal_handlers
      trap('SIGINT') {stop}
      trap('SIGTERM') {stop}
      trap('SIGUSR1') {GC.start; @show_synapses = !@show_synapses}
    end

    def install_periodic_actions
      @fast_synapse_timer = EM::PeriodicTimer.new(FAST_TIMER_FREQUENCY / 1000) { synapse_timer_block }
      EM.add_periodic_timer(1) { clear_busy_jids }
      EM.add_periodic_timer(2) { monitor_connection_status }
      EM.add_periodic_timer(8) { GC.start }
      EM.add_timer(1.0 / 1000) { connect } # Try to connect immediately after startup.
      EM.add_timer(1) { advertise_resources } # run once, a second after startup.
    end

    def synapse_timer_block
      queue_size = @synapse_queue.size
      fire_synapses

      if @fast_synapse_timer && queue_size == 0
        @fast_synapse_timer.cancel
        @fast_synapse_timer = nil
        @slow_synapse_timer = EM::PeriodicTimer.new(SLOW_TIMER_FREQUENCY / 1000) { synapse_timer_block }
      elsif @slow_synapse_timer && queue_size > 0
        @slow_synapse_timer.cancel
        @slow_synapse_timer = nil
        @fast_synapse_timer = EM::PeriodicTimer.new(FAST_TIMER_FREQUENCY / 1000) { synapse_timer_block }
      end
    end

    def add_client(token, client)
      clients[token] = client
    end

    def remove_client(token)
      clients.delete(token)
    end

    def clear_queues
      # I don't think there's any reason for this, anymore.
    end

    def enqueue_synapse(synapse)
      @synapse_queue << synapse
    end

    def fire_synapses
      logger.debug "QUEUE: #{@synapse_queue.length}" if @show_synapses
      @synapse_queue.fire(@show_synapses)
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
        unless @conn.open? || @connection_in_progress
          @connection_in_progress = true
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
        @connection_in_progress = false
        unless @conn.authenticated?
          logger.debug "authenticating"
          success = @conn.authenticate(@jid.node, @password, @jid.resource) {}
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
        @connection_in_progress = false
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

    def remove_busy_jid(jid, client)
      if locking_client = @busy_jids[jid]
        if locking_client == client
          @busy_jids.delete(jid)
        else
          raise "Busy JID Client mismatch for #{jid.inspect}, offending client is #{client.inspect}"
        end
      else
        # raise "Busy JID Client not found for #{jid.inspect}, offending client is #{client.inspect}"
      end
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

      EM.run do
        install_periodic_actions
        EM.attach(LM::Sink.file_descriptor, LmDispatcher)
      end
    end

    def direct_op(op_type, to, *args)
      entree = SousChef.prepare(*args)
      op = Vertebra::Op.new(op_type, entree.args)
      logger.debug("#direct_op #{op_type} #{to} #{args.inspect} for #{self}")
      Vertebra::Protocol::Client.start(self, op, to)
    end

    def op(op_type, to, *args)
      # The old op() model doesn't work in an evented architecture, since it is blocking.
      # TODO: Figure out if we need to simulate it somehow (i.e. fake fibers with threads
      # to make it look blocking) or if direct_op() is sufficient.
      raise "This is probably not needed"
    end

    # #discover takes as args a list of resources either in string form
    # (/foo/bar) or as instances of Vertebra::Resource.  It returns a list
    # of jids that will handle any of the resources.
    def discover(*resources)
      logger.debug "DISCOVERING: #{resources.inspect} on #{@herault_jid}"
      direct_op('/security/discover', @herault_jid, *resources.collect {|r| Vertebra::Resource === r ? r.to_s : r})
    end

    def request(op_type, *raw_args)
      # If the scope of the request is going to be specified, it should be
      # passed via a symbol as the first arg -- :single or :all.  That arg
      # will be removed from the list before issuing the request.  If a
      # scope is not given, :all is the assumed scope.

      entree = SousChef.prepare(*raw_args)

      entree.args['__scope__'] = entree.scope

      discoverer = Vertebra::Synapse.new
      discoverer.callback do
        requestor = Vertebra::Synapse.new
        discoverer[:client] = discover(op_type, *entree.resources)
        requestor.condition do
          discoverer[:client].done? ? :succeeded : :deferred
        end
        requestor.callback do
          jids = discoverer[:client].results
          if Array === jids
            target_jids = jids.concat(entree.jids)
          else
            target_jids = jids['jids'].concat(entree.jids)
          end

          if jids.empty?
            discoverer[:results] = []
          elsif entree.scope == :all
            gather(discoverer, target_jids, op_type, entree.args)
          else
            gather_one(discoverer, target_jids.sort_by { rand }, op_type, entree.args)
          end
        end
        enqueue_synapse(requestor)
      end
      enqueue_synapse(discoverer)

      discoverer
    end

    def send_iq(iq)
      @conn.send(iq)
    rescue Exception => e
      logger.debug "KABOOM!  #{e}"  
    end

    def send_packet(to,typ,packet_id,packet) # This exists only for debugging purposes.
      iq = LM::Message.new(to,LM::MessageType::IQ)
      iq.node['id'] = packet_id.to_s
      iq.node.raw_mode = true
      iq.root_node.set_attribute('type',typ)
      iq.node.value = packet.to_s
      logger.debug("SENDING TEST PACKET #{iq.node}")
      send_iq(iq)
    end

    def send_packet_with_reply(to,typ,packet_id,packet) # This exists only for debugging purposes.
      iq = LM::Message.new(to,LM::MessageType::IQ)
      iq.node['id'] = packet_id.to_s
      iq.node.raw_mode = true
      iq.root_node.set_attribute('type',typ)
      iq.node.value = packet.to_s
      @conn.send_with_reply(iq) {|resp_iq| logger.debug "DEBUGGING PACKET: #{resp_iq.node.to_s}" }
    end

    # This method queue an op for each jid, and returns a hash containing the
    # client protocol object for each.
    def scatter(jids, op_type, args)
      ops = {}
      jids.each do |jid|
        logger.debug "scatter# #{op_type} | #{jid} | #{args.inspect}"
        ops[jid] = direct_op(op_type, jid, args)
      end
      ops
    end

    def gather(discoverer, jids, op_type, args)
      ops = scatter(jids, op_type, args)

      gatherer = Vertebra::Synapse.new
      gatherer.condition do
        num_finished = 0
        ops.each { |jid, client| num_finished += 1 if client.done? }
        num_finished == ops.size ? :succeeded : :deferred
      end
      gatherer.callback do
        results = []
        ops.each { |jid, client| results << client.results unless client.results.empty? }

        discoverer[:results] = results
      end
      enqueue_synapse(gatherer)
    end

    def gather_one(discoverer, jids, op_type, args)
      nexter = Vertebra::Synapse.new
      jid = jids.shift
      op = direct_op(op_type, jid, args)
      nexter.condition do
        op.done? ? :succeeded : :deferred
      end
      
      nexter.callback do
        if op.state == :commit
          discoverer[:results] = op.results
        else
          # The client is done, but it is not in :commit state, so it failed.
          # If there are other jids to try, do so.
          if jids.length > 0
            gather_one(discoverer, jids, op_type, args)
          else
            # There were no other jids to try, so we're out of targets, and have
            # no results; this returns an error.
            # Clarify: Should the code do this, or should it return an array
            # of ALL of the errors that were received?
            discoverer[:results] = [:error, "Operation Failed"]
          end
        end        
      end
      
      enqueue_synapse(nexter)
    end


    def parse_token(iq)
      iq['token']
    end

    def handle_iq(iq)
      logger.debug "handle_iq: #{iq.node}"
      @unhandled = true

      handle_errors(iq)
      handle_duplicates(iq)

      handle_op_set(iq)
      handle_op_result(iq)

      handle_ack_result(iq)
      handle_ack_set(iq)

      handle_nack_result(iq)
      handle_nack_set(iq)

      handle_data_result(iq)
      handle_data_set(iq)
      
      handle_final_result(iq)
      handle_final_set(iq)

      handle_error_result(iq) # Note: Something about this seems wrong, but maybe I'm just confused; Double check it!

      handle_unhandled(iq)
    end

    def handle_errors(iq)
      if iq.sub_type == LM::MessageSubType::ERROR
        @unhandled = false
        error = iq.node.get_child('error')
        # Check to see if the error is one we want to retry.
        if error['type'] == 'wait' || (error['type'] == 'cancel' && error['code'].to_s == '503')
          # If it is...RETRY
          # First, find the conversation that caused the error.
          token = parse_token(iq.node.child)
          # Then resend.
          @clients[token].resend if @clients.has_key?(token) # Don't call resend() if the client can't be found.
        else
          token = parse_token(iq.node.child)
          client = @clients[token]
          if client
            logger.debug "XMPP error: #{error.to_s}; aborting"
            error_handler = Vertebra::Synapse.new
            error_handler[:state] = :error
            error_handler.callback {logger.debug "error"; client.process_data_or_final(iq, :error, error)}
            enqueue_synapse(error_handler)
          end
        end
      end
    end

    def handle_duplicates(iq)
      if @unhandled
        # Handle Duplicates
        # To do this, check the received stanza against the deja_vu_map.
        #   match by token
        #     id
        token = parse_token(iq.node.child)
        iq_id = iq.node['id']
        if duplicate = @deja_vu_map[token][iq_id]
          @unhandled = false
          # If there is a match, then we have seen it before in an existing
          # conversation.
          # If we have seen it before, then either:
          # It's a RESULT, we'll just drop it on the floor.
          # Or it is a SET, and we need to do something sensible with it.

          if iq.sub_type == LM::MessageSubType::SET
            # The sensible thing to do with a IQ-set that we have already
            # seen is to just synthesize an IQ-result.
            result_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ)
            result_iq.node.raw_mode = true
            result_iq.node.set_attribute("id", iq.node.get_attribute("id"))
            result_iq.node.set_attribute('xml:lang','en')
            result_iq.node.value = iq.node.child
            result_iq.root_node.set_attribute('type', 'result')

            response = Vertebra::Synapse.new
            response[:name] = 'duplicate response'
            response.condition { connection_is_open_and_authenticated? }
            response.callback do
              logger.debug "Agent#handle_duplicates: sending #{result_iq.node}"
              send_iq(result_iq)
            end
            enqueue_synapse(response)
          end
        end
      end
    end

    def handle_op_set(iq)
      # Protocol::Server
      if @unhandled && (op = iq.node.get_child('op')) && iq.sub_type == LM::MessageSubType::SET
        token = parse_token(op)
        @deja_vu_map[token][iq.node['id']] = iq
        logger.debug "in op set; token: #{token}/#{token.size}"
        @unhandled = false
        # The protocol object will take care of enqueing itself.
        logger.debug "Creating server protocol"
        Vertebra::Protocol::Server.new(self,iq)
      end
    end
    
    def handle_op_result(iq)
      # Protocol::Client
      if @unhandled && (op = iq.node.get_child('op')) && iq.sub_type == LM::MessageSubType::RESULT
        logger.debug "Got token: #{parse_token(op).inspect}"
        token = parse_token(op)
        left, right = token.split(':',2)
        client = @clients[left]
        if client
          clients[token] = client
          clients.delete(left)
          client.is_ready
          @unhandled = false
        end
      end
    end
    
    def handle_ack_result(iq)
      #Protocol::Server
      if @unhandled && (ack = iq.node.get_child('ack')) && iq.sub_type == LM::MessageSubType::RESULT
        server = @servers[parse_token(ack)]
        if server
          ack_handler = Vertebra::Synapse.new
          ack_handler[:client] = server
          ack_handler[:state] = :ack
          ack_handler.callback {logger.debug "ack"; server.process_operation}
          enqueue_synapse(ack_handler)
          @unhandled = false
        end
      end
    end
    
    def handle_ack_set(iq)
      # Protocol::Client
      if @unhandled && (ack = iq.node.get_child('ack')) && iq.sub_type == LM::MessageSubType::SET
        token = parse_token(ack)
        client = @clients[token]
        if client
          @deja_vu_map[token][iq.node['id']] = iq
          ack_handler = Vertebra::Synapse.new
          ack_handler[:client] = client
          ack_handler[:state] = :ack
          ack_handler.callback {logger.debug "ack"; client.process_ack_or_nack(iq, :ack, ack)}
          enqueue_synapse(ack_handler)
          @unhandled = false
        end
      end
    end

    def handle_nack_result(iq)
      #Protocol::Server
      if @unhandled && (nack = iq.node.get_child('nack')) && iq.sub_type == LM::MessageSubType::RESULT
        server = @servers[parse_token(nack)]
        if server
          ack_handler = Vertebra::Synapse.new
          ack_handler[:client] = server
          ack_handler[:state] = :nack
          ack_handler.callback {logger.debug "nack"; server.process_nack_result}
          enqueue_synapse(ack_handler)
          @unhandled = false
        end
      end
    end
    
    def handle_nack_set(iq)
      # Protocol::Client
      if @unhandled && (nack = iq.node.get_child('nack')) && iq.sub_type == LM::MessageSubType::SET
        token = parse_token(nack)
        client = @clients[token]
        if client
          @deja_vu_map[token][iq.node['id']] = iq
          nack_handler = Vertebra::Synapse.new
          nack_handler[:client] = client
          nack_handler[:state] = :nack
          nack_handler.callback {logger.debug "nack"; client.process_ack_or_nack(iq, :nack, nack)}
          enqueue_synapse(nack_handler)
          @unhandled = false
        end
      end
    end
    
    def handle_data_result(iq)
      # Protocol::Server
      if @unhandled && (result = iq.node.get_child('data')) && iq.sub_type == LM::MessageSubType::RESULT
        server = @servers[parse_token(result)]
        if server
          result_handler = Vertebra::Synapse.new
          result_handler[:client] = server
          result_handler[:state] = :result
          result_handler.callback {logger.debug "data"; server.process_data_result(result)}
          enqueue_synapse(result_handler)
          @unhandled = false
        end
      end
    end
    
    def handle_data_set(iq)
      # Protocol::Client
      if @unhandled && (result = iq.node.get_child('data')) && iq.sub_type == LM::MessageSubType::SET
        token = parse_token(result)
        client = @clients[token]
        if client
          @deja_vu_map[token][iq.node['id']] = iq
          result_handler = Vertebra::Synapse.new
          result_handler[:client] = client
          result_handler[:state] = :result
          result_handler.callback {logger.debug "data"; client.process_data_or_final(iq, :result, result)}
          enqueue_synapse(result_handler)
          @unhandled = false
        end
      end
    end

    def handle_final_result(iq)
      # Protocol::Server
      if @unhandled && (final = iq.node.get_child('final')) && iq.sub_type == LM::MessageSubType::RESULT
        token = parse_token(final)
        server = @servers[token]
        if server
          final_handler = Vertebra::Synapse.new
          final_handler[:client] = server
          final_handler[:state] = :final
          final_handler.callback {logger.debug "final"; @servers.delete(token); server.process_final}
          enqueue_synapse(final_handler)
          @unhandled = false
        end
      end
    end
    
    def handle_final_set(iq)
      # Protocol::Client
      if @unhandled && (final = iq.node.get_child('final')) && iq.sub_type == LM::MessageSubType::SET
        token = parse_token(final)
        client = @clients[token]
        if client
          @deja_vu_map[token][iq.node['id']] = iq
          final_handler = Vertebra::Synapse.new
          final_handler[:client] = client
          final_handler[:state] = :final
          final_handler.callback {logger.debug "final"; client.process_data_or_final(iq, :final, final)}
          enqueue_synapse(final_handler)
          @unhandled = false
        end
      end
    end

    def handle_error_result(iq)
      # Protocol::Server
      if @unhandled && (error = iq.node.get_child('error')) && iq.sub_type == LM::MessageSubType::RESULT
        token = parse_token(error)
        server = @servers[token]
        if server
          error_handler = Vertebra::Synapse.new
          error_handler[:client] = server
          error_handler[:state] = :error
          error_handler.callback {logger.debug "error"; @servers.delete(token); server.process_error}
          enqueue_synapse(error_handler)
          @unhandled = false
        end
      end
    end
  
    def handle_unhandled(iq)
      if @unhandled
        # Make sure this isn't something that we just don't care about, like an
        # <iq type="result"><session>

        case iq.node.child.name
        when 'session'
          # Yeah, don't care about these
          logger.debug "#{iq.node} getting ignored; uninteresting"
        else
          # TODO: This feels kind of gross, below.  I want a better API for doing
          # this stuff without inserting transport layer specific manipulations
          # into the core of the code.
          if iq.sub_type == LM::MessageSubType::SET
            error_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ)
            error_iq.node['type'] = 'error'
            error_iq.node.set_attribute("id", iq.node.get_attribute("id"))
            error_iq.node.set_attribute('xml:lang','en')
            
            error_iq.node.raw_mode = true
            error_iq.node.value = iq.node.child
            error_iq.node.add_child('error')
            error_iq.node.child['code'] = '400'
            error_iq.node.child['type'] = 'modify'
            error_iq.node.child.add_child('bad-request')
            error_iq.node.child.child['xmlns'] = 'urn:ietf:params:xml:ns:xmpp-stanzas'
            @conn.send(error_iq)
            logger.debug("Sending error: #{error_iq.node}")
          end
        end
      end
    end

    def advertise_op(resources, ttl = @ttl)
      logger.debug "ADVERTISING: #{resources.inspect}"
      direct_op('/security/advertise', @herault_jid, :resources => resources, :ttl => ttl)
    end

    def unadvertise_op(resources)
      logger.debug "UNADVERTISING: #{resources.inspect}"
      direct_op('/security/advertise', @herault_jid, :resources => resources, :ttl => 0)
    end

    def advertise_resources
      unless provided_resources.empty?
        advertise_op(provided_resources)
        unless @advertise_timer_started
          EM.add_periodic_timer(@ttl * 0.9) {advertise_op(provided_resources,@ttl)}
          @advertise_timer_started = true
        end
      end
    end

    def provided_resources
      actors = @dispatcher.actors || []
      actors.collect {|actor| actor.provides }.flatten
    end

    def self.default_status
      (File.exists?("/proc") ? File.read("/proc/loadavg") : `uptime`.split(":").last).gsub("\n", '')
    end
 
    def determine_scope(*args)
      args.each do |arg|
        if arg.respond_to?(:has_key?) && arg.has_key?('__scope__')
          return arg['__scope__'].to_s.intern
        end
      end
      :all
    end

    private

    def add_include_path(path)
      $:.unshift path
    end
  end
end
