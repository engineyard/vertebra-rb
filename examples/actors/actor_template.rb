# Copyright 2008, Engine Yard, Inc.
#
# As this is example code, it is released into the Public Domain.

require 'thor'
require 'vertebra/actor'
require 'vertebra/extensions'

# Actors are written as a Ruby class, namespaced into a relevant module, which
# uses a simple DSL to describe defined operations, and which contains methods
# that implement the operations.  This file describes each of the parts of an
# actor.  It may be used as a template for writing your own actors, as well.

module VertebraYOURTOOL # e.x. VertebraGemTool or VertebraXen or VertebraMarcoPolo

  class Actor < Vertebra::Actor

    # In most cases, one should not need to manually describe the resources
    # provided by the actor, as they will be determined automatically from
    # the bound operations (see bind_op below), but if there is a need to list
    # resources for which no operations are bound, use the 'provides' clause:
    #
    # provides '/RESOURCE1', '/RESOURCE2', '/RESOURCE3'
    #
    # The 'provides' clauses are additive, so more than one may be used:
    #
    # provides '/RESOURCE1'
    # provides '/RESOURCE2'
    # provides '/RESOURCE3'

    # The 'bind_op' clause creates a relationship between a resource/op path
    # and a method name which implements the operation.  The list of resources
    # provided by the actor will be determined automatically from the bound
    # operations.

    bind_op "/RESOURCE/OPNAME", :op_method_name

    # The 'desc' clause creates a relationship between a resource/op path and
    # a short description of what the operation does.

    desc "/RESOURCE/OPNAME", "A short description of the operation goes here"

    # The 'method_options' clause specifies the attributes which MUST be
    # included in the <op> request as well as those which MAY be included.

    method_options :thing => :optional, :widget => :required
    
    # After using the DSL clauses to describe the op, it is good practice to
    # follow the descriptive clauses with the method or methods which provide
    # the operations functionality.  All operation methods must take a single
    # argument.  That argument should default to an empty hash.
    # The return value of the method will be marshalled into XML and sent back
    # over the wire to the requesting agent.  See Vertebra::Marshal for
    # specific information regarding how different object types are marshaled.
    
    def op_method_name(options = {})
      thing = options['thing']
      widget = options['widget']

      # spawn() is a method provided in Vertebra::Actor.  It starts the given
      # command, with the given command line arguments, in an external process.
      # The standard output of the command is captured and made available to
      # a provided block, and the result of the block is placed, along with the
      # stderror and stdout, into a hash that is marshalled for the op's
      # response.
      output = spawn("external_command", "command_line_argument") do |output|
        list = output.chomp.split("\n").reject { |g| g =~ /^\*\*\* / || g.empty? }
        list.inject({}) do |hsh, str|
          md = str.match(/(.*)\W\((.*)\)/)
          hsh[md[1]] = md[2].split(", ")
          hsh
        end
      end
    end

  end
end
