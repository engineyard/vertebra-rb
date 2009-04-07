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

module Vertebra
  class Actor
    class << self
      def method_added(meth)
        meth = meth.to_s

        return if meth == "initialize"
        return if !public_instance_methods.include?(meth) || !@description

        method_descriptions[meth] = @description
        @operations.each do |operation|
          provided_operations.add(operation)
          operation_methods[operation] << meth
        end
        @description, @operations = nil, nil
      end

      def desc(description)
        @description = description
      end

      def bind_op(operation)
        @operations ||= []
        @operations << Vertebra::Resource.parse(operation)
      end

      def lookup_op(operation)
        operation_methods[operation]
      end

      def provides(*args)
        resources = args.last.is_a?(Hash) ? args.pop : {}
        raise ArgumentError, "#{args.inspect} need to have keys for each resource" if args.any?
        resources.each do |key,resource|
          provided_resources.add(key, resource)
        end
      end

      def provided_operations
        @provided_operations ||= KeyedResources::ResourceSet.new
      end

      def operation_methods
        @operation_methods ||= Hash.new do |h,operation|
          h[operation] = []
        end
      end

      def provided_resources
        @provided_resources ||= KeyedResources.new
      end

      def method_descriptions
        @method_descriptions ||= {}
      end
    end

    def initialize(agent, deployment_resources, config)
      @agent = agent
      @deployment_resources = deployment_resources || KeyedResources.new
      @config = config
      logger.debug "#{self.class} starting with config: #{config.inspect}"
    end

    def provided_operations
      self.class.provided_operations
    end

    def provided_resources
      @deployment_resources + self.class.provided_resources
    end

    def providing_operation?(operation)
      provided_operations.matches?(operation)
    end

    def providing_resources?(resources)
      resources.all? do |key,resource|
        provided_resources.matches?(key, resource)
      end
    end

    # TODO: This method needs to be refactored.  Nay, it begs to be refactored.
    # Also, there are probably some error handling cases that need better
    # testing.
    def handle(job)
      method_names = self.class.lookup_op(job.operation)
      raise NoMethodError, "No method provides the #{job.operation} operation" unless method_names

      # This synapse is responsible for accumulating the results from any of the
      # actors which are running.
      gatherer = Vertebra::Synapse.new

      # Dispatch to each method.  The return results can be either a direct
      # value, or a synapse.  If it is a synapse, then the synapse will be
      # checked periodically for results.
      # The gatherer has results when everyone it is monitoring has results.

      r = []

      method_iterator = Vertebra::Synapse.new

      case job.scope
      when :single
        randomized_method_names = method_names.sort_by { rand }
        method_name = nil
        method_result = :no_result

        method_iterator.condition do
          if !randomized_method_names.empty?
            method_name = randomized_method_names.pop unless method_name

            if method_name && method_result == :no_result
              begin
                if self.method(method_name).arity == 2
                  method_result = self.send(method_name, job.args, job)
                else
                  method_result = self.send(method_name, job.args)
                end
              rescue Exception => e
                logger.error "Got an exception: #{e.message}"
                logger.debug e.backtrace.inspect
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
            begin
              if self.method(method_name).arity == 2
                method_result = self.send(method_name, job.args, job)
              else
                method_result = self.send(method_name, job.args)
              end
            rescue Exception => e
              logger.error "Got an exception: #{e.message}"
              logger.debug e.backtrace.inspect
              method_result = e
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

    def logger
      Vertebra.logger
    end
  end
end
