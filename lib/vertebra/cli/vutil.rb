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

require 'erb'

module Vertebra
  module CLI
    class Util < Thor

      desc "generate_config", "Generate a sample config file for a vertebra agent"
      method_options :config_file => :optional, :username => :optional, :domain => :optional, :type => :optional, :password => :optional

      def generate_config(options = {})
        default_username = `hostname`
        default_domain = `hostname -d`
        config_path = options['config_file'] || '/etc/vertebra/agent.yml'
        config_dir = File.dirname(config_path)
        domain = options['domain'] || default_domain.chomp
        username = options['username'] || default_username.chomp
        type = options['type'] || "agent"
        password = options['password'] || Vertebra.gen_token
        config = YAML.load(File.read(File.dirname(__FILE__)+"/../config/#{type}_template.yml"))
        config['jid'] = "#{username}@#{domain}/agent"
        config['password'] = password
        config['default_resources'] = Vertebra::Resource.parse_hostname(username).collect {|resource| resource.to_s } rescue nil
        FileUtils.mkdir_p(config_dir) unless File.exists?(config_dir)
        File.open(config_path, "w") { |f| f.write(config.to_yaml) }
        puts "Generated user #{username} with password #{password} and config file #{config_path}"
        puts "Add this user to ejabberd using this command line: ejabberdctl register #{username} <JABBER-HOSTNAME> #{password}"
      end

      desc "setup_monit", "Setup monit and add a monitrc file for vertebra"
      method_options :domain => :optional, :monitrc => :boolean

      def setup_monit(options = {})
        abort "Not implemented yet"
      end
    end
  end
end
