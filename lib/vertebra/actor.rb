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
      attr_accessor :provided_resources

      def bind_op(resource, method_name)
        key = Vertebra::Resource.new(resource.to_s)
        provides "/#{key.res.first}"
        (@op_table ||= {})[key] = method_name
      end

      def lookup_op(resource)
        @op_table[resource]
      end

      def provides(*resources)
        (@provided_resources ||= []) << resources.collect { |r| Vertebra::Resource.new(r) }
        @provided_resources.flatten!
        @provided_resources.uniq!
      end
    end

    attr_accessor :default_resources, :agent

    # use same method signature as Thor
    def initialize(opts = {}, *args)
      @default_resources = nil
      @agent = nil
    end

    def handle_op(op_type, args, &yielder)
      resource = Vertebra::Resource.new(op_type.to_s)
      method_name = self.class.lookup_op(resource)
      raise NoMethodError unless method_name
      self.send(method_name, args, &yielder)
    end

    # Specify the resources that the actor provides.  The interface is additive.  That is,
    # calling it again will add to the existing set of provided resources.

    def provides
      (default_resources || []) + self.class.provided_resources
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

  end
end

