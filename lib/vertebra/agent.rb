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
require 'vertebra/synapse'
require 'vertebra/synapse_queue'

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

    attr_accessor :dispatcher, :herault_jid, :clients, :servers, :conn
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
      @deja_vu_map = Hash.new {|h1,k1| h1[k1] = Hash.new {|h2,k2| h2[k2] = {}}
      @synapse_queue = Vertebra::SynapseQueue.new

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

    def stop
      @main_loop.quit
    end

    def install_signal_handlers
      trap('SIGINT') {stop}
      trap('SIGTERM') {stop}
      trap('SIGUSR1') {GC.start; File.open('/tmp/objdump','w+') {|fh| GC.start; ObjectSpace.each_object {|o| fh.puts "#{o} -- #{o.inspect}"}}; GC.start}
    end

    def install_periodic_actions
      GLib::Timeout.add(20) { fire_synapses; true }
      GLib::Timeout.add(1000) { clear_busy_jids; true }
      GLib::Timeout.add(2000) { monitor_connection_status; true }
      GLib::Timeout.add(800) { GC.start; true}
      GLib::Timeout.add(1) { connect; false } # Try to connect immediately after startup.
      GLib::Timeout.add(1000) { advertise_resources; false } # run once, a second after startup.
    end

    def add_client(token, client)
      clients[token] = client
    end

    def clear_queues
      # I don't think there's any reason for this, anymore.
    end

    def enqueue_synapse(synapse)
      @synapse_queue << synapse
    end

    def fire_synapses
      @synapse_queue.fire
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
        raise "Busy JID Client not found for #{jid.inspect}, offending client is #{client.inspect}"
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

      discoverer = Vertebra::Synapse.new
      discoverer.callback do
        requestor = Vertebra::Synapse.new
        discoverer[:client] = discover(op_type,*resources)
        requestor.condition do
          discoverer[:client].done? ? :succeeded : :deferred
        end
        requestor.callback do
          jids = discoverer[:client].results
          if Array === jids
            target_jids = jids.concat(specific_jids)
          else
            target_jids = jids['jids'].concat(specific_jids)
          end

          if jids.empty?
            discoverer[:results] = []
          elsif scope == :all
            gather(discoverer, target_jids, op_type, *cooked_args)
          else
            gather_first(discoverer, target_jids.sort_by { rand }.first, op_type, *cooked_args)
          end
        end

        enqueue_synapse(requestor)
      end
      enqueue_synapse(discoverer)

      discoverer
    end

    def send_iq(iq)
      @conn.send(iq)
    end

    # This method queue an op for each jid, and returns a hash containing the
    # client protocol object for each.
    def scatter(jids, op_type, *args)
      ops = {}
      jids.each do |jid|
        logger.debug "scatter# #{op_type}/#{jid}/#{args.inspect}"
        ops[jid] = direct_op(op_type, jid, *args)
      end
      ops
    end

    def gather_first(discoverer, jids, op_type, *args)
      ops = scatter(jids, op_type, *args)
      errors = [:error]
      result = nil

      gatherer = Vertebra::Synapse.new
      # Check to see if at least one of the clients has finished as is in
      # The :commit state, or that all of them have finished and none were
      # in the :commit state.
      gatherer.condition do
        finished = false
        num_finished = 0

        ops.each do |jid, client|
          num_finished += 1
          if client.done? && client.state == :commit
            finished = true
            break
          end
        end

        if finished
          :succeeded
        elsif num_finished == ops.size
          :failed
        else
          :deferred
        end
      end

      # If there was a successful op, find it and return its result.
      gatherer.callback do
        result = nil
        ops.each do |jid, client|
          if client.done? && client.state == :commit
            result = client.results
            break
          end
        end

        discoverer[:results] = result
      end

      # If there were no successful results, return the array of errors.
      gatherer.errback do
        results = [:error]
        ops.each do |jid, client|
          results << client.results unless client.results.empty?
        end
        discoverer[:results] = results
      end
      enqueue_synapse(gatherer)
    end

    def gather(discoverer, jids, op_type, *args)
      ops = scatter(jids, op_type, *args)

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

    def parse_token(iq)
      iq['token']
    end

    def handle_iq(iq)
      # TODO: Refactor this enormous method.

      logger.debug "handle_iq: #{iq.node}"
      unhandled = true

      # Handle errors
      if iq.sub_type == LM::MessageSubType::ERROR
        unhandled = false
        error = iq.node.get_child('error')
        # Check to see if the error is one we want to retry.
        if error['type'] == 'wait' || (error['type'] == 'cancel' && error['code'].to_s == '503')
          # If it is...RETRY
          # First, find the conversation that caused the error.
          token = parse_token(iq.node.child)
          # Then resend.
          @clients[token].resend
        else
          token = parse_token(iq.node.child)
          client = @clients[token]
          if client
            logger.debug "XMPP error: #{error.to_s}; aborting"
            error_handler = Vertebra::Synapse.new
            error_handler[:state] = :error
            error_handler.callback {logger.debug "error"; client.process_result_or_final(iq, :error, error)}
            enqueue_synapse(error_handler)
          end
        end
      end

      # Handle Duplicates
      # To do this, check the received stanza against the deja_vu_map.

      # If there is a match, then we have seen it before in an existing
      # conversation.
      # If we have seen it before, then either:
      # It's a RESULT, and we'll just drop it on the floor.
      # Or it is a SET, and we need to do something sensible with it.

      # Protocol::Server
      if unhandled && (op = iq.node.get_child('op')) && iq.sub_type == LM::MessageSubType::SET
        token = parse_token(op)
        logger.debug "in op set; token: #{token}/#{token.size}"
        unhandled = false
        # The protocol object will take care of enqueing itself.
        logger.debug "Creating server protocol"
        Vertebra::Protocol::Server.new(self,iq)
      end

      # Protocol::Client
      if unhandled && (op = iq.node.get_child('op')) && iq.sub_type == LM::MessageSubType::RESULT
        logger.debug "Got token: #{parse_token(op).inspect}"
        token = parse_token(op)
        left, right = token.split(':',2)
        client = @clients[left]
        if client
          clients[token] = client
          clients.delete(left)
          client.is_ready
          unhandled = false
        end
      end

      #Protocol::Server
      if unhandled && (ack = iq.node.get_child('ack')) && iq.sub_type == LM::MessageSubType::RESULT
        server = @servers[parse_token(ack)]
        if server
          ack_handler = Vertebra::Synapse.new
          ack_handler[:client] = server
          ack_handler[:state] = :ack
          ack_handler.callback {logger.debug "ack"; server.process_operation}
          enqueue_synapse(ack_handler)
          unhandled = false
        end
      end

      # Protocol::Client
      if unhandled && (ack = iq.node.get_child('ack')) && iq.sub_type == LM::MessageSubType::SET
        client = @clients[parse_token(ack)]
        if client
          ack_handler = Vertebra::Synapse.new
          ack_handler[:client] = client
          ack_handler[:state] = :ack
          ack_handler.callback {logger.debug "ack"; client.process_ack_or_nack(iq, :ack, ack)}
          enqueue_synapse(ack_handler)
          unhandled = false
        end
      end

      # Protocol::Client
      if unhandled && nack = iq.node.get_child('nack')
        client = @clients[parse_token(nack)]
        if client
          nack_handler = Vertebra::Synapse.new
          nack_handler[:client] = client
          nack_handler[:state] = :nack
          nack_handler.callback {logger.debug "nack"; client.process_ack_or_nack(iq, :nack, nack)}
          enqueue_synapse(nack_handler)
          unhandled = false
        end
      end

      # Protocol::Server
      if unhandled && (result = iq.node.get_child('result')) && iq.sub_type == LM::MessageSubType::RESULT
        server = @servers[parse_token(result)]
        if server
          result_handler = Vertebra::Synapse.new
          result_handler[:client] = server
          result_handler[:state] = :result
          result_handler.callback {logger.debug "result"; server.process_result_result(result)}
          enqueue_synapse(result_handler)
          unhandled = false
        end
      end

      # Protocol::Client
      if unhandled && (result = iq.node.get_child('result')) && iq.sub_type == LM::MessageSubType::SET
        client = @clients[parse_token(result)]
        if client
          result_handler = Vertebra::Synapse.new
          result_handler[:client] = client
          result_handler[:state] = :result
          result_handler.callback {logger.debug "result"; client.process_result_or_final(iq, :result, result)}
          enqueue_synapse(result_handler)
          unhandled = false
        end
      end

      # Protocol::Server
      if unhandled && (final = iq.node.get_child('final')) && iq.sub_type == LM::MessageSubType::RESULT
        token = parse_token(final)
        server = @servers[token]
        if server
          final_handler = Vertebra::Synapse.new
          final_handler[:client] = server
          final_handler[:state] = :final
          final_handler.callback {logger.debug "final"; @servers.delete(token); server.process_final}
          enqueue_synapse(final_handler)
          unhandled = false
        end
      end

      # Protocol::Client
      if unhandled && (final = iq.node.get_child('final')) && iq.sub_type == LM::MessageSubType::SET
        client = @clients[parse_token(final)]
        if client
          final_handler = Vertebra::Synapse.new
          final_handler[:client] = client
          final_handler[:state] = :final
          final_handler.callback {logger.debug "final"; client.process_result_or_final(iq, :final, final)}
          enqueue_synapse(final_handler)
          unhandled = false
        end
      end

      # Protocol::Server
      if unhandled && (error = iq.node.get_child('error')) && iq.sub_type == LM::MessageSubType::RESULT
        token = parse_token(error)
        server = @servers[token]
        if client
          error_handler = Vertebra::Synapse.new
          error_handler[:client] = server
          error_handler[:state] = :error
          error_handler.callback {logger.debug "error"; @servers.delete(token); server.process_error}
          enqueue_synapse(ack_handler)
          unhandled = false
        end
      end

      if unhandled
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
            error_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::ERROR)
            error_iq.node.set_attribute("id", iq.node.get_attribute("id"))
            error_iq.node.set_attribute('xml:lang','en')
            error_iq.node.add_child iq.node
            error_iq.node.add_child('error')
            error_iq.node.child['code'] = 400
            error_iq.node.child['type'] = 'modify'
            error_iq.node.add_child('bad-request')
            error_iq.node.child.next['xmlns'] = 'urn:ietf:params:xml:ns:xmpp-stanzas'
            @conn.send(error_iq)
            logger.debug('Sending error: #{error_iq}')
          end
        end

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
      unless provided_resources.empty?
        advertise_op(provided_resources)
        unless @advertise_timer_started
          GLib::Timeout.add_seconds(@ttl * 0.9) {advertise_op(provided_resources,@ttl)}
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

    private

    def add_include_path(path)
      $:.unshift path
    end
  end
end
