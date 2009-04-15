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

require 'rubygems'
require 'open4'

module Vertebra
  module CLI
    class VAgent < Thor
      before :load_config, :create_agent

      desc "start [options]", "Start a Vertebra agent"
      method_options :config_file => :optional, :jid => :optional, :password => :optional, :use_drb => :boolean, :drb_port => :optional, :background => :optional,
                     :debug => :boolean, :jabber_debug => :boolean, :herault_jid => :optional, :log_path => :optional, :pid_path => :optional, :test_mode => :boolean

      def start(options = {})
        @agent.start(options[:background])
      rescue Exception => e
        Vertebra.logger.error e.message
        Vertebra.logger.error e.backtrace
      end

      desc "stop", "Stop a running Vertebra agent"
      method_options :config_file => :optional

      def stop(options = {})
        @agent.stop
      end

      desc "restart", "Restart a running Vertebra agent"
      method_options :config_file => :optional

      def restart(options = {})
        stop
        sleep 2
        start
      end

      desc "status", "Get a running agent process status"
      method_options :config_file => :optional

      def status(options = {})
        pid = IO.read(@config[:pid_path]).chomp.to_i rescue nil
        if pid
          if Process.is_running?(pid)
            psdata = `ps up #{pid}`.split("\n").last.split
            memory = (psdata[5].to_i / 1024)
            puts "The agent is alive, using #{memory}MB of memory"
          else
            puts "The agent is not running but has a stale pid file at #{@config[:pid_path]}"
          end
        else
          puts "The agent is not running."
        end
      end

      private

      def load_config(options = {})
        options.symbolize_keys!
        path = options[:config_file] || "/etc/vertebra/agent.yml"
        if File.exists?(path)
          @config = YAML.load(File.read(path))
          @config.merge(options)
          @config.symbolize_keys!
          Vertebra.setup_logger(@config)
        else
          raise ArgumentError, "Config file #{path} doesn't exist. Specify another with the -c option."
        end
      end

      def create_agent(options)
        @agent = Agent.new(@config[:jid], @config[:password], @config)
      end
    end
  end
end
