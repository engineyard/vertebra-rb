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

require File.dirname(__FILE__) + '/../vertebra'

module Vertebra
  #class BaseAgent < ::Jabber::Simple
  class BaseAgent

    include Vertebra::Daemon

    attr_accessor :drb_port, :client
    attr_reader :rooms, :jid, :pubsub

    def initialize(jid, password, opts={})

      Vertebra.config = @opts = opts

      raise(ArgumentError, "Please provide at least a Jabber ID and password") if !jid || !password

      Vertebra::Daemon.setup_pidfile unless @opts[:background]

      # Multiuser chat rooms
      @rooms = {}
      # pubsub servers
      @pubsub = {}

      @drb_port = @opts[:drb_port]

      #Jabber.debug = @opts[:jabber_debug] || false

      add_include_path(@opts[:actor_path]) if @opts[:actor_path]
      add_include_path(File.dirname(__FILE__) + "/../../spec/mocks") if @opts[:test_mode]

      @jid = Vertebra::JID.new(jid)
      @jid.resource ||= 'agent'
      @password = password
      @opts[:sleep] ||= 0.001

      self.accept_subscriptions = false

    end

    def queue(queue)
      @queues ||= Hash.new { |h,k| h[k] = Queue.new }
      @queues[queue]
    end

		def dequeue(queue, non_blocking = true, max_items = 100, &block)
			queue_items = []
			max_items.times do
				queue_item = queue(queue).pop(non_blocking) rescue nil
				break if queue_item.nil?
				queue_items << queue_item
				yield queue_item if block_given?
			end
			queue_items
		end

		def accept_subscriptions?
			@accept_subscriptions = true if @accept_subscriptions.nil?
			@accept_subscriptions
		end

		def accept_subscriptions=(accept_status)
			@accept_subscriptions = accept_status
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

      logger.info "Connecting as #{@jid}..."
      connect!
      logger.info "Connected."
      #add_default_callbacks
      @main_loop.run
    end

    def client
      @conn
    end

    def connect!
      @conn.open do |result|
        logger.debug "Connection open block"
        if result
          logger.debug "Connection opened correctly"
          @conn.authenticate(@jid.node, @password, "agent") do |auth_result|
            unless auth_result
              logger.debug "Failed to authenticate"
              @main_loop.quit
            end
            advertise_resources
          end
        else
          logger.debug "Failed to connect"
          @main_loop.quit
        end
      end  
    end

    def add_default_callbacks
      @client.add_iq_callback do |iq|
        queue(:received_iqs) << iq
      end
    end

    def add_include_path(path)
      $:.unshift path
    end

    def clear_queues
      (@queues||[]).each {|queue| logger.debug "CLEARING QUEUE: #{queue}"; queue.clear }
    end

    def start_event_loop
      dead_cycles     = 0
      exponent        = 0

      loop do
        received_packet = false

        # Iq packet callbacks
        received_iqs do |iq|
          handle_iq(iq)
          received_packet = true
        end

        # chat message handling
        received_messages do |msg|
          handle_chat_message(msg)
          received_packet = true
        end

        # pubsub event handling
        received_pubsub_events do |event|
          handle_pubsub_event(event)
          received_packet = true
        end

        # presence updates
        received_presence_updates do |presence|
          handle_presence(presence)
          received_packet = true
        end

        # new subscriptions
        new_subscriptions do |friend, presence|
          handle_new_subscription(friend, presence)
          received_packet = true
        end

        # subscription requests
        subscription_requests do |friend, presence|
          handle_subscription_request(friend, presence)
          received_packet = true
        end

        if received_packet
          dead_cycles = 0
          exponent    = 0
        elsif
          dead_cycles = dead_cycles + 1

          if dead_cycles > 2 ** exponent
            exponent = exponent + 1 if exponent < 8
          end

          sleep_time = @opts[:sleep] * ( 2 ** exponent )

          sleep sleep_time
        end
      end
    end

    def handle_iq(iq)
      # must implement callback in subclass
    end

    def handle_authorized_iq(iq)
      # must implement callback in subclass
    end

    def handle_unauthorized_iq(iq)
      # must implement callback in subclass
    end

    def handle_result(iq)
      # must implement callback in subclass
    end

    def handle_invite(msg)
      # must implement callback in subclass
    end

    def handle_chat_message(msg)
      # must implement callback in subclass
    end

    def handle_presence_update(friend, new_presence)
      # must implement callback in subclass
    end

    def handle_new_subscription(friend, presence)
      # must implement callback in subclass
    end

    def handle_subscription_request(friend, presence)
      # must implement callback in subclass
    end

    def received_messages(&block)
      dequeue(:received_messages, &block)
    end

    def received_pubsub_events(&block)
      dequeue(:received_pubsub_events, &block)
    end

    def received_iqs(&block)
      dequeue(:received_iqs, &block)
    end

    def received_presence_updates(&block)
      dequeue(:received_presence_updates, &block)
    end

    def received_results(&block)
      dequeue(:received_results, &block)
    end

    def received_error_results(&block)
      dequeue(:received_error_results, &block)
    end

    def recieved_authorized_iqs(&block)
      dequeue(:recieved_authorized_iqs, &block)
    end

    def recieved_unauthorized_iqs(&block)
      dequeue(:recieved_unauthorized_iqs, &block)
    end

    def final_results(&block)
      dequeue(:final_results, true, 1, &block)
    end

    def received_presences(&block)
      dequeue(:received_presences, &block)
    end

    def inspect_queues
      qs = []
      @queues_mutex ||= Mutex.new
      @queues_mutex.synchronize {
        @queues.each do |k,v|
          qs << "#{k} :  #{v.size}"
        end
      }
      qs
    end

  end
end
