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

require 'drb'
module Vertebra

  # Base class for command line tools, inherits from Thor.
  # Provides an agent DRb and handles resource extraction for operations.
  class BaseRunner < Thor

    @@global_method_options = {}

    NO_AGENT_ERROR = "This tool requires a local vertebra agent with an open DRb port."

    # Open a DRb connection to the locally running agent and pass options to Thor
    def initialize(opts = {}, *args)
      @agent = DRbObject.new(nil, "druby://localhost:#{opts[:drb_port] || '7620'}")
      super
    end

    # If a set of global options are set in the runner class, in the
    # @@global_method_options class variable, then setting method options with
    # all_method_options merges them for you.

    def self.all_method_options(opts = {})
      self.method_options(@@global_method_options.merge(opts))
    end

    # Thor doesn't appear to provide a way to get the original options hash
    # back from a Thor::Options object.  However, it can be reconstructed from
    # the options.
    def self.backconvert_thor_switches_to_options(thor_options)
      switches = thor_options ? thor_options.instance_variable_get(:@switches) : {}
      opts = {}
      switches.each {|k,v| opts[k[2,-1]] = v}
      opts
    end

    # By calling this at the start of the runner, it will setup default runner
    # tasks for every op defined in the actor.
    def self.inherit_from_actor(actor_class)
      @actor_class = actor_class
      actor_class.instance_variable_get(:@tasks).each do |key, task|

        #skip it if it's usage isn't in /resource/op format.
        next unless task.usage =~ /\/.*?\/.*?/

        # Setup a default runner task based on the setup of the actor task.
        resource, op = describe_from_actor(key)

        class_eval(<<ECODE)
def #{key}(options = {})
  result = broadcast("#{op}","#{resource}",options)
  puts result.inspect
end
ECODE

      end
    end

    def self.describe_from_actor(task_name)
      task = @actor_class.instance_variable_get(:@tasks)[task_name]
      return unless task
      
      parts = task.usage.split('/')
      resource = "/#{parts.first}"
      op = "/#{parts[1..-1].join('/')}"
      desc_opts = [task_name, task.description]

      desc(*desc_opts)
      all_method_options(backconvert_thor_switches_to_options(task.opts))
      [resource, op]
    end

    private

    # Helper to pull out all the location-oriented resources and return them in the correct format, along with the
    # target 'operation' resource and finally the remaining options hash as arguments to the operation
    def build_resources(resource, opts = {})
      if opts['only_nodes'] && opts['node']
        raise ArgumentError, "Cannot mix only_nodes and node options"
      end

      location_resources = []

      opts.each do |key, val|

        # Thor adds short options to list. Remove them.
        opts.delete(key[0,1]) if opts[key[0,1]]

        if %w(cluster node slice gateway).include?(key)
          location_resources << "/#{key}/#{val}"
          opts.delete(key)
        end

        # only_nodes becomes a '/node' resource
        if key =~ /only_(.*)s/
          location_resources << "/#{$1}"
          opts.delete(key)
          # Thor adds short options to list
        end
      end
      location_resources + [resource] + [opts]
    end

    # Broadcasts a command through an agent DRb with the appropriate extracted resource
    def broadcast(command, resource, opts = {})
      resources = build_resources(resource, opts)
      @agent.broadcast(command, *resources)
    end

  end
end
