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

require 'vertebra/resource'
require 'open4'
require File.dirname(__FILE__) + "/../../vendor/thor/lib/thor"

module Vertebra

  class ActorInternalError < StandardError; end

  # Multiple actors run inside of a Vertebra::Agent instance. Actors, and
  # therefore agents, provide resources for operations to be performed on.
  # Actors inherit some resources from their Agent's environment, defined
  # as :default_resources in the agent's config file.
  #
  # Actors can be any class. The only requirement is that the class contain
  # a constant named RESOURCES which names the resources provided by that actor.
  #
  # Simple example actor:
  #
  # class GemManager
  #   RESOURCES = ["/gem"]
  #
  #   def list(args = {})
  #     arr = []
  #     `gem list`.each do |line|
  #       arr << line.chomp unless line =~ /LOCAL/ or line.chomp.empty?
  #     end
  #     arr
  #   end
  # end
  #
  # If the above actor was running on slice ey01-s00141 then it would provide
  # the following resources in total:
  #
  #  '/cluster/ey01', '/slice/s00141', '/gem'
  #
  # This means that in order for this class to be selected during dispatch, the
  # incoming operation must contain the same resources or a superset of these
  # resources:
  #
  # <op type='list'>
  #   <res name='cluster'>/cluster/ey01</res>
  #   <res name='slice'>/slice/s00141</res>
  #   <res name='gem'>/gem</res>
  # </op>
  #
  # You can think of actors kinda like Merb or Rails controllers. It's where
  # the action happens.
  #
  # Like with controllers, be aware that all public actor methods are available
  # to an agent.
  #

  class Actor < Thor

    class << self
      def provided_resources
        @provided_resources || []
      end

      def bind_op(resource, method_name)
        key = Vertebra::Resource.parse(resource.to_s)
        provides key
        (@op_table ||= Hash.new {|h,k| h[k] = []})[key] << method_name
      end

      def op_table
        @op_table
      end

      def lookup_op(resource)
        @op_table[resource]
      end

      def provides(*resources)
        (@provided_resources ||= []) << resources.collect { |r| Vertebra::Resource.parse(r) }
        @provided_resources.flatten!
        @provided_resources.uniq!
      end
    end

    attr_accessor :config, :default_resources, :agent

    # use same method signature as Thor
    def initialize(opts = {}, *args)
      @config = opts || {}
      logger.debug "#{self.class} got config #{@config.inspect}"
      @default_resources = nil
      @agent = nil
    end

    def op_path_resources
      self.class.op_table.keys
    end

    # TODO: This method needs to be refactored.  Nay, it begs to be refactored.
    # Also, there are probably some error handling cases that need better
    # testing.

    def handle_op(operation, op_type, scope, args)
      resource = Resource.parse(op_type.to_s)
      method_names = self.class.lookup_op(resource)
      raise NoMethodError unless method_names

      # This synapse is responsible for accumulating the results from any of the
      # actors which are running.
      gatherer = Vertebra::Synapse.new

      # Dispatch to each method.  The return results can be either a direct
      # value, or a synapse.  If it is a synapse, then the synapse will be
      # checked periodically for results.
      # The gatherer has results when everyone it is monitoring has results.

      r = []

      method_iterator = Vertebra::Synapse.new

      case scope
      when :single
        randomized_method_names = method_names.sort_by { rand }
        method_name = nil
        method_result = :no_result

        method_iterator.condition do
          if !randomized_method_names.empty?
            method_name = randomized_method_names.pop unless method_name

            if method_name && method_result == :no_result
              begin
                method_result = self.send(method_name, operation, args)
              rescue Exception => e
                logger.error "Got an exception: #{e.message}"
                logger.debug e.backtrace
                method_name = nil
                method_result = :no_result
              else
                @agent.enqueue_synapse(method_result) if Vertebra::Synapse === method_result
                r[0] = method_result
              end
            end

            if method_result && method_result != :no_result && (!(Vertebra::Synapse === method_result) || (Vertebra::Synapse === method_result && method_result.has_key?(:results)))
              :succeeded
            elsif method_result && method_result != :no_result && Vertebra::Synapse == method_result && method_result.has_key?(:error)
              method_name = nil
              method_result = :no_result
              r.delete(0)
              :deferred
            else
              :deferred
            end
          else
            r = []
            :succeeded
          end
        end
      else
        method_iterator.condition do
          method_names.each do |method_name|
            if self.method(method_name).arity > 1
              method_result = self.send(method_name, operation, args)
            else
              method_result = self.send(method_name, args)
            end
            
            r << method_result
            @agent.enqueue_synapse(method_result) if Vertebra::Synapse === method_result
          end
          :succeeded
        end
      end

      method_iterator.callback do
        gatherer.condition do
          r.all? do |res|
            if Vertebra::Synapse === res
              res.has_key?(:results)
            else
              true
            end
          end ? :succeeded : :deferred
        end

        gatherer.callback do
          gatherer[:results] = r.collect {|res| Vertebra::Synapse === res ? res[:results] : res }
        end

        @agent.enqueue_synapse(gatherer)
      end

      @agent.enqueue_synapse(method_iterator)

      gatherer
    end

    # Specify the resources that the actor provides.  The interface is additive.  That is,
    # calling it again will add to the existing set of provided resources.

    def provides
      (default_resources || []) + self.class.provided_resources
    end

    def can_provide?(required_resources)
      required_resources.all? do |req|
        provides.any? do |provide|
          provide >= req
        end
      end
    end

    def to_s
      "<Actor[#{self.class.name}]: provides=#{provides.map{|n| n.to_s }.join(', ')}>"
    end

    def spawn(arg, *argv, &block)
      # setup output hash
      output = {:result => '', :stderr => ''}
      default_options = {'stdout' => output[:result], 'stderr' => output[:stderr]}

      # add default options to fill output hash
      if argv.size > 1 and Hash === argv.last
        argv.last.merge!(default_options)
      else
        argv.push default_options
      end


      # catch any spawn errors and return
      begin
        status = Open4::spawn(arg, *argv)
      rescue Open4::SpawnError => e
        raise ActorInternalError, e.message
      end

      if block_given?
        formatted_output = yield(output[:result])
        output[:result] = formatted_output
      end

      output.merge({:status => status})
    end

    def logger
      Vertebra.logger
    end

  end
end

