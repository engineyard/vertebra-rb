# This is generated code.  You should replace this with a copyright statement
# and licensing information.

require 'rubygems'
require '<%= @config[:name] %>/actor'

#####
#
# The runner is used when running operations defined in an actor from the command line.
#
# DO NOT PUT YOUR OPERATIONS CODE IN THIS FILE; IT BELONGS IN actor.rb
#
# The code will create a default set of runner tasks, based upon the actor tasks, automatically.
# For any tasks that require special option handling or formatting of the results, you may override
# the default.  See the examples/actors/runner_template.rb for an example of how to do this.
#
#####

begin
  require 'vertebra/base_runner'
rescue LoadError
  puts "Please install the vertebra gems."
  exit
end

begin
  require 'thor'
rescue LoadError
  puts "Please install the thor gem."
  exit
end

module Vertebra
  class Runner<%= @config[:class_name] %> < BaseRunner

  ### Put a hash of any options which are to be defined for all tasks into the
  # global_method_options class variable.  Leave it commented out if there are
  # no global options.
  #
  # @@global_method_options = ...

  inherit_from_actor(<%= @config[:class_name] %>::Actor)

  end
end
