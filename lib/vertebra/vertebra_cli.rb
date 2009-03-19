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

# This file is a reimplementation of xmpp4r's rexmladdons. As such, it depends
# on some parts of REXML.

require 'optparse'
require 'rubygems'
require 'vertebra'
require 'vertebra/agent'
require 'yaml'

module Vertebra

  # This just eats everything called on it.
  class SwallowEverything
    def method_missing(*args); end
  end

  def self.disable_logging
    # If logging is disabled (which will be the normal mode of execution for
    # the command line tool), then replace the logger with an object that just
    # swallows all methods called on it.

    @@logger = SwallowEverything.new
    Vertebra.instance_variable_set('@logger',@@logger)
  end

  class VertebraCLI
    def self.read_config_file(filename)
      path = File.expand_path(filename)
      if File.readable? path
        options = YAML.load(File.read(path))
        keys_to_symbols(options)
      else
        {}
      end
    end

    # Very little command line parsing is done.  A check will be made for a
    # --single or --all flag.  A check will be made for a --config flag that
    # points to a config file, and the first remaining arg in the list will
    # be assumed to be the operation to invoke.

    def self.parse_commandline
      options ={:config_file => '~/.vertebra/vertebra',
                :scope => :all,
                :iterations => 1,
                :yaml => true}

      ARGV << '--help' if ARGV.empty?

      OptionParser.new do |opts|
        opts.banner = "vertebra /OP [options] [arguments]"

        opts.on('--single',
                'Dispatch the op with a scope of \'single\'.') do
          options[:scope] = :single
        end

        opts.on('--all',
                'Dispatch the op with a scope of \'all\'.',
                '   (default)') do
          options[:scope] = :all
        end

        opts.on('--config FILENAME',
                'Specify a config file to use.',
                '   (defaults to ~/.vertebra/vertebra)') do |v|
          options[:config_file] = v
        end

        opts.on('--jid JID',
                'The JID to use to connect to XMPP.') do |v|
          options[:jid] = v
        end

        opts.on('--password PASSWORD',
                'The password for the XMPP JID.') do |v|
          options[:password] = v
        end

        opts.on('-v', '--[no-]verbose', "Toggle verbose mode") do |v|
          options[:verbose] = v
        end

        opts.on('--inspect',
                'Display results in the Ruby inspect format.') do |v|
          options[:yaml] = !v
        end

        opts.on('--yaml',
                'Display results as YAML.',
                '   (default)') do |v|
          options[:yaml] = v
        end

        opts.on('--log', 'Enable logging') do |v|
          options[:enable_logging] = v
        end

        opts.on('--discover',
                'Do discovery only.',
                '   (This is primarily a developer tool.)') do |v|
          options[:discovery_only] = v
        end

        opts.on('--herault-jid JID',
                'The JID for Herault') do |v|
          options[:herault_jid] = v
        end
        
        opts.on('-n', '--iterations NUMBER','The number of times to do the op.') do |v|
          options[:iterations] = v.to_i > 0 ? v.to_i : 1
        end

        opts.on('-?', '-h', '--help') do
          puts opts
          exit
        end
      end.parse!

      # Pull the op
      options[:op] = ARGV.shift

      # Now search the rest of the args to identify the resources

      op_args = []
      ARGV.each do |arg|
        if arg =~ /string:([^\s]*)/
          op_args << $1
        elsif arg =~ /string:(["'])([^\1]*)/ # TODO: This regexp can be improved.
          op_args << $2
        elsif arg =~ /res:([^\s]*)/
          op_args << Vertebra::Resource.new($1)
        else
          op_args << arg
        end
      end
      options[:op_args] = op_args
      options
    end

    def self.dispatch_request
      puts "Initializing agent with #{@jid}:#{@password}" if @verbose
      agent = Vertebra::Agent.new(@jid, @password, @options)

      EM.next_tick do
        puts "Making #{@options[:iterations]} request#{@options[:iterations] > 1 ? 's' : ''} for #{@op} #{@scope} #{@op_args.inspect}" if @verbose
        rq = []
        @options[:iterations].times do
          rq << agent.request(@op,@scope,*@op_args)
        end
        @check_timer = EM::PeriodicTimer.new(0.01) do
          dc = 0
          rq.each {|r| dc += 1 if r[:results]}
          if dc == @options[:iterations]
            agent.stop
            rq.each {|r| show_results(r[:results])}
            @check_timer.cancel
            @check_timer = nil
          end
        end
      end

      agent.start
    end

    def self.show_results(results)
      if @yaml
        puts results.to_yaml
      else
        puts results.inspect
      end
    end

    def self.run
      cli_options = parse_commandline
      file_options = read_config_file(cli_options.delete(:config_file))
      @options = file_options.merge cli_options
      Vertebra::disable_logging unless @options.delete :enable_logging
      ## TODO: Fix this so that we don't assign an asston of fields.
      [:jid, :op, :op_args,
       :password, :scope, :verbose, :yaml].each do |option|
        instance_variable_set("@#{option}", @options.delete(option))
      end
      dispatch_request
    end

    private

    def self.keys_to_symbols(hash)
      newhash = {}
      hash.each {|k,v| newhash[k.to_s.intern] = v}
      newhash
    end
  end
end
