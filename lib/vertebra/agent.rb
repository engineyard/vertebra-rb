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
require 'vertebra/packet_memory'

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
    MIN_TIMER_QUANTUM = 5.0
    attr_accessor :drb_port

    attr_reader :jid

    attr_reader :dispatcher, :herault_jid, :clients, :servers, :conn, :packet_memory
    attr_reader :ttl, :opts

    def initialize(jid, password, opts = {})
      default_opts = {:herault_jid => 'herault@localhost/herault'}
      @opts = default_opts.merge(opts)

      raise(ArgumentError, "Please provide at least a Jabber ID and password") if !jid || !password

      @drb_port = @opts[:drb_port]

      add_include_path(@opts[:actor_path]) if @opts[:actor_path]
      add_include_path(File.dirname(__FILE__) + "/../../spec/mocks") if @opts[:test_mode]

      @jid = Vertebra::JID.new(jid)
      @jid.resource ||= 'agent'
      @password = password

      @idle_ticks = 0
      @idle_threshold = SLOW_TIMER_FREQUENCY / FAST_TIMER_FREQUENCY

      @pending_clients = []
      @active_clients = []
      @connection_in_progress = false
      @authentication_in_progress = false
      #@deja_vu_map = Hash.new {|h1,k1| h1[k1] = {} }
      @packet_memory = Vertebra::PacketMemory.new
      @synapse_queue = Vertebra::SynapseQueue.new

      @advertise_timer_started = false
      @herault_jid = @opts[:herault_jid]
      @ttl = @opts[:ttl] || 3600 # Default TTL for advertised resources is 3600 seconds.

      @conn = LM::EventedConnection.new
      @conn.jid = @jid.to_s

      install_signal_handlers

      # TODO: Add options for these intervals, instead of a hardcoded timing?

      set_callbacks

      deployment_resources = KeyedResources.new
      deployment_resources_hash = @opts[:deployment_resources] || {}
      unless deployment_resources_hash.is_a?(Hash)
        raise ArgumentError, "Deployment resources must be specified as a Hash: got #{deployment_resources_hash.inspect}"
      end
      deployment_resources_hash.each do |key,value|
        deployment_resources.add(key, value)
      end

      @dispatcher = Dispatcher.new(self, deployment_resources)
      @clients, @servers = {},{}

      @show_synapses = false

      # register actors specified in the config
      @dispatcher.register(@opts[:actors]) if @opts[:actors]
    end

    def stop
      EM.stop if EM.reactor_running?
      daemon.stop
    end

    def daemon
      @daemon ||= Daemon.new(@opts)
    end

    def install_signal_handlers
      trap('SIGINT') {stop}
      trap('SIGTERM') {stop}
      trap('SIGUSR1') {GC.start; @show_synapses = !@show_synapses}
    end

    def install_periodic_actions
      @fast_synapse_timer = EM::PeriodicTimer.new(FAST_TIMER_FREQUENCY / 1000) { synapse_timer_block }
      EM.set_timer_quantum(5)
      EM.add_periodic_timer(2) { monitor_connection_status }
      EM.add_periodic_timer(8) { GC.start }
      EM.add_timer(0.001) { connect } # Try to connect immediately after startup.
      if @herault_jid
        EM.add_timer(1) { advertise_resources } # run once, a second after startup.
      end
    end

    def limited_timer_quantum(q)
      q <= MIN_TIMER_QUANTUM ? MIN_TIMER_QUANTUM.to_i : q
    end

    def synapse_timer_block
      queue_size = @synapse_queue.size
      fire_synapses

      if @fast_synapse_timer && queue_size == 0
        @idle_ticks += 1
        if @idle_ticks > @idle_threshold
          @fast_synapse_timer.cancel
          @fast_synapse_timer = nil
          @slow_synapse_timer = EM::PeriodicTimer.new(SLOW_TIMER_FREQUENCY / 1000) { synapse_timer_block }
          EM.set_timer_quantum(SLOW_TIMER_FREQUENCY.to_i)
          @idle_ticks = 0
        end
      elsif @slow_synapse_timer && queue_size > 0
        @slow_synapse_timer.cancel
        @slow_synapse_timer = nil
        @fast_synapse_timer = EM::PeriodicTimer.new(FAST_TIMER_FREQUENCY / 1000) { synapse_timer_block }
        EM.set_timer_quantum(limited_timer_quantum(FAST_TIMER_FREQUENCY))
        @idle_ticks = 0
      else
        @idle_ticks = 0
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

    def do_or_enqueue_synapse(synapse)
      if synapse && synapse.respond_to?(:deferred_status?)
        ds = synapse.deferred_status?
        case ds
        when :succeeded
          synapse.set_deferred_status(:succeeded,synapse)
        when :failed
          synapse.set_deferred_status(:failed,synapse)
        else
          enqueue_synapse(synapse)
        end
      end
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

    def start(background = false)
      if background
        daemon.run do
          start(false)
        end
        return
      end

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

    def request(operation, scope, args = {}, jids = nil, &block)
      token = Vertebra.gen_token

      synapse = Outcall.start(self, Resource.parse(operation), token, scope, args, jids)

      # TODO: Should this have a timeout on it? I think probably, yes.
      requestor = Vertebra::Synapse.new
      requestor.condition { connection_is_open_and_authenticated? }
      requestor.condition { synapse.has_key?(:results) ? true : :deferred }
      if block_given?
        requestor.callback do
          yield synapse[:results]
        end
      else
        requestor.callback do
          requestor[:results] = synapse[:results]
        end
      end

      do_or_enqueue_synapse(requestor)
      requestor
    end

    def send_iq(iq)
      logger.debug "Sending iq: #{iq.root_node.to_s}"
      @conn.send(iq)
    rescue Exception => e
      logger.debug "KABOOM!  #{e}"
    end

    def send_result(jid, id, children = [], indirect_block = nil, &direct_block)
      result_iq = LM::Message.new(jid, LM::MessageType::IQ, LM::MessageSubType::RESULT)
      result_iq.node.raw_mode = false
      result_iq.node["id"] = id
      result_iq.node['xml:lang'] = 'en'

      children.each do |op_tuple|
        name, attributes = op_tuple
        result_iq.node.add_child name
        attributes.each {|k,v| result_iq.node.child[k] = v }
      end

      block = direct_block || indirect_block
      logger.debug "BLOCK: #{block.inspect}"

      response = Vertebra::Synapse.new
      response.condition { connection_is_open_and_authenticated? }
      response.callback do
        send_iq(result_iq)
        logger.debug "CB BLOCK: #{block.inspect}"
        block.call if block
      end

      do_or_enqueue_synapse(response)
      result_iq
    end

    def send_iq_with_synapse(iq, protocol)
      synapse = Vertebra::Synapse.new
      synapse.condition { connection_is_open_and_authenticated? }
      synapse.callback do
        protocol.last_message_sent = iq
        packet_memory.set(iq.node['to'], iq.node.child['token'], iq.node['id'],iq)
        send_iq(iq)
      end
      do_or_enqueue_synapse(synapse)
    end

    def parse_token(iq)
      iq['token']
    end

    def handle_iq(iq)
      logger.debug "handle_iq #{Time.now.to_f}: #{iq.node}"

      handle_duplicates(iq)
      if iq.sub_type == LM::MessageSubType::ERROR
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
        return
      end

      Stanza.handle(self, iq)
    end

    def handle_duplicates(iq)
      # Handle Duplicates
      # To do this, check the received stanza against the packet memory.
      #   match by token
      #     id
      # token = parse_token(iq.node.child)
      jid = iq.node['from']
      id = iq.node['id']
      if duplicate = @packet_memory.get_by_jid_and_id(jid,id)
        # If there is a match, then we have seen it before in an existing
        # conversation.
        # If we have seen it before, then either:
        # It's a RESULT, we'll just drop it on the floor.
        # Or it is a SET, and we need to do something sensible with it.

        if iq.sub_type == LM::MessageSubType::SET
          # The sensible thing to do with a IQ-set that we have already
          # seen is to just synthesize an IQ-result.
          result_iq = LM::Message.new(iq.node["from"], LM::MessageType::IQ)
          result_iq.node.raw_mode = true
          result_iq.node["id"] = id
          result_iq.node['xml:lang'] = 'en'
          result_iq.node.value = iq.node.child
          result_iq.root_node['type'] = 'result'

          response = Vertebra::Synapse.new
          response[:name] = 'duplicate response'
          response.condition { connection_is_open_and_authenticated? }
          response.callback do
            logger.debug "Agent#handle_duplicates: sending #{result_iq.node}"
            send_iq(result_iq)
          end
          enqueue_synapse(response)
        end
        true
      else
        false
      end
    end

    def handle_unhandled(iq)
      # TODO: This feels kind of gross, below.  I want a better API for doing
      # this stuff without inserting transport layer specific manipulations
      # into the core of the code.
      if iq.sub_type == LM::MessageSubType::SET
        error_iq = LM::Message.new(iq.node["from"], LM::MessageType::IQ)
        error_iq.node['type'] = 'error'
        error_iq.node["id"] = iq.node["id"]
        error_iq.node['xml:lang'] = 'en'

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

    def advertise_op(operations, resources, ttl)
      logger.debug "ADVERTISING start: ttl=#{ttl}, operations=#{operations.inspect}, resources=#{resources.inspect}"
      request('/security/advertise', :direct, {:operations => operations, :resources => resources, :ttl => ttl}, [@herault_jid]) do |response|
        logger.debug "ADVERTISING complete: ttl=#{ttl}, operations=#{operations.inspect}, resources=#{resources.inspect}"
        logger.debug "response from advertise: #{response.inspect}"
      end
    end

    def advertise_resources
      if provided_operations.any? && provided_resources.any?
        advertise_op(provided_operations, provided_resources, @ttl)

        unless @advertise_timer_started
          EM.add_periodic_timer(@ttl * 0.9) do
            advertise_op(provided_operations, provided_resources, @ttl)
          end
          @advertise_timer_started = true
        end
      end
    end

    def provided_operations
      operations = []
      @dispatcher.actors.map do |actor|
        operations += actor.provided_operations.to_a
      end
      logger.debug "provided operations: #{operations.inspect}"
      operations
    end

    def provided_resources
      resources = KeyedResources.new
      @dispatcher.actors.map do |actor|
        resources.merge(actor.provided_resources)
      end
      logger.debug "provided resources: #{resources.inspect}"
      resources.to_hash
    end

    def self.default_status
      (File.exists?("/proc") ? File.read("/proc/loadavg") : `uptime`.split(":").last).gsub("\n", '')
    end

    private

    def add_include_path(path)
      $:.unshift path
    end

    def logger
      Vertebra.logger
    end
  end
end
