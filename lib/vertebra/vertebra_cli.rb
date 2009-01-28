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
	end	
	
	class VertebraCLI
		def self.read_config_file
			@opts = {}
			cfg = nil
			if String === @config_file
				path = File.expand_path(@config_file)
				if File.exist? path
					cfg = File.read(path)
				end
			elsif @config_file.respond_to?(:read)
				cfg = @config_file.read
			end
			if cfg
				@opts = YAML.load(cfg)
				@jid ||= @opts['jid']
				@password ||= @opts['password']
				@opts.delete('jid')
				@opts.delete('password')
				@opts = keys_to_symbols(@opts)
			end
		end
		
		# Very little command line parsing is done.  A check will be made for a
		# --single or --all flag.  A check will be made for a --config flag that
		# points to a config file, and the first remaining arg in the list will
		# be assumed to be the operation to invoke.
		
		def self.parse_commandline
			@scope = :all
			@config_file = '~/.vertebra/vertebra'
			@client = nil
			@jid = nil
			@password = nil
			@verbose = false
			@yaml = true
			@enable_logging = false
			@discovery_only = false
			
			# First, find the few command line flags that need special handling.
			args_to_remove = []
			ARGV.each_with_index do |arg, idx|
				case arg
				when '--single'
					@scope = :single
					args_to_remove << idx
				when '--all'
					@scope = :all
					args_to_remove << idx
				when '--config'
					@config_file = ARGV[idx + 1] if ARGV[idx + 1]
					args_to_remove << idx
					args_to_remove << idx + 1
				when '--jid'
					@jid = ARGV[idx + 1] if ARGV[idx + 1]
					args_to_remove << idx
					args_to_remove << idx + 1
				when '--password'
					@password = ARGV[idx + 1] if ARGV[idx + 1]
					args_to_remove << idx
					args_to_remove << idx + 1
				when '--verbose'
					@verbose = true
					args_to_remove << idx
				when '--inspect'
					@yaml = false
					args_to_remove << idx
				when '--yaml'
					@yaml = true
					args_to_remove << idx
				when '--log'
					@enable_logging = true
					args_to_remove << idx
				when '--discover'
					@discovery_only = true
					args_to_remove << idx
				when '--herault-jid'
					@opts[:herault_jid] = ARGV[idx + 1] if ARGV[idx + 1]
					args_to_remove << idx
					args_to_remove << idx + 1
				when '--help'
					puts <<EHELP
vertebra /OP [vertebra-flags] [op arguments]
	--all             Dispatch the op with a scope of 'all'.  This is the default.
	--single          Dispatch the op with a scope of 'single'.
	--config FILENAME Specify a config file to use. If not specified, this
										defaults to HOME/.vertebra/vertebra
	--jid JID         The JID to use to connect to vertebra. This overrides
										anything specified in the configuration file.
	--password PWD    The password to use with the jid to connect to vertebra.
	--herault-jid JID The JID of the herault instance to query for discovery.
	--yaml            Transform the op results to YAML before displaying them.
										This tends to make them more human readable, and is the
										default.
	--inspect         Display the results of the op in the Ruby inspect format.
	--log             Turn logging on. This will write an agent.PID.log file to
										the temp directory, logging the CLI actions. Off by default.
	--discover        Do discovery only. This is primarily a developer tool.
	--help            Show this text.
	
Anything on the command line that is not one of the above flags is passed to
the operation.  In order to differentiate between resources and other strings
on the command line, one should preface any resource with 'res:'.

i.e.

vertebra /gem/list res:/cluster/rd00 res:/slice/0

All resources that are provided on the command line will be used for discovery.

Primarily as a developer aid, one may also provide specific jids:

vertebra /gem/list jid:rd00-s00000@localhost/agent
EHELP
					exit
				end
			end
			
			Vertebra::disable_logging unless @enable_logging
			
			args_to_remove.each {|arg_idx| ARGV[arg_idx] = :gone}
			intermediate_args = ARGV.reject {|arg| arg == :gone}
			
			# Pull the op
			@op = intermediate_args.shift
			
			# Now search the rest of the args to identify the resources
			
			@parsed_args = []
			intermediate_args.each do |arg|
				if arg =~ /string:([^\s]*)/
					@parsed_args << $1
				elsif arg =~ /string:(["'])([^\1]*)/ # TODO: This regexp can be improved.
					@parsed_args << $2
				elsif arg =~ /res:([^\s]*)/
					@parsed_args << Vertebra::Resource.new($1)
				else
					@parsed_args << arg
				end
			end
		end
				
		def self.dispatch_request
			puts "Initializing agent with #{@jid}/#{@password}" if @verbose
			agent = Vertebra::Agent.new(@jid, @password, @opts)
			
			GLib::Timeout.add(10) do
				if @discovery_only
					puts "Doing discovery #{[@op,@parsed_args].flatten.inspect}" if @verbose
					resources = @parsed_args.select {|r| Vertebra::Resource == r}
					@client = agent.discover(@op,*resources)
					GLib::Timeout.add(50) do
						if @client.done?
							show_results(@client.results)
							agent.stop
							false
						else
							true
						end
					end
				else
					puts "Making request for #{@op}" if @verbose
					request = agent.request(@op,@scope,*@parsed_args)
					GLib::Timeout.add(50) do
						if request[:results]
							agent.stop
							show_results(request[:results])
							false
						else
							true
						end
					end # GLib::Timeout
				end
				false
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
			parse_commandline
			read_config_file
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
