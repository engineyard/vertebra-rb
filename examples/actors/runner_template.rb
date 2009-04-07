# Copyright 2008, Engine Yard, Inc.
#
# As this is example code, it is released into the Public Domain.

require 'rubygems'

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

# A runner class provides an interface for making calls to an actor from the
# command line.  This file documents the essential parts of a runner, and may
# be used as a template for writing your own runner.

module Vertebra
  # Choose a unique name for the class that indicates which resource or actor
  # that the runner is intended to work with.

  class VGem < BaseRunner

    # @@global_method_options specifies options that exist for all actor
    # invocation methods.  See the documentation on method_options in the
    # actor_template.rb file, or examine the Thor documentation if you
    # don't understand how these options work.

    @@global_method_options = {:node => :optional, :cluster => :required, :only_nodes => :boolean, :slice => :optional}

    # In a lot of cases, the information that was already given in the actor
    # class is sufficient to define a runner task for calling the op. The
    # inherit_from_actor call will generate default tasks from all of the
    # operations that were defined for the actor.

    inherit_from_actor(VertebraGemtool::Actor)

    # If the default task is insufficient, one may override it.  One reason to
    # do this would be if the result set returned by the operation needs some
    # formatting to make it human friendly.  To override a task, one needs to
    # give it a description, and specify the options, much like with the
    # actors.

    # As with an actor, a 'desc' clause associates a command with a short
    # description of what it does.

    desc "list", "Get a list of gems"

    # Also as wtih an actor, the 'all_method_options' clause describes which
    # method parameters MAY be present, and which MUST be present.

    all_method_options :filter => :optional

    # It is quite likely, even if one is doing processing on the result set
    # that is returned, that the description and method options for the runner
    # task will be the same as what was specified for an actor.  If that is
    # the case, do not write separate desc/all_method_options lines.  Just use
    # this:
    #
    # describe_from_actor(TASKNAME)
    #
    # It will create a description and method options based on those in the actor.
    # i.e.
    #
    # describe_from_actor(:list)

    # Following the description of the available command, the method or methods
    # which implement functionality for it should appear.  Just like with
    # actors, these methods should take a single argument which defaults to a
    # hash.

    def list(opts = {})
      gems = broadcast('list', '/gem', opts)
      gems.each { |host, gems| puts "\n#{host}";puts "---"; puts gems.is_a?(Array) ? gems.join("\n") : gems }
    end

  end
end
