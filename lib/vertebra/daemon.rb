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
  class Daemon
    def initialize(config)
      @config = config
    end

    def daemonize(starter)
     logger.debug "Daemonizing..."
      fork do
        Process.setsid
        exit if fork
        setup_pidfile
        File.umask 0000
        STDIN.reopen "/dev/null"
        STDOUT.reopen @config[:log_path], "a"
        STDERR.reopen STDOUT
        trap("TERM") { exit }
        starter.call
      end
    end

    def stop(sig = 15)
      begin
        pid = IO.read(pidfile).chomp.to_i
        Process.kill(sig, pid)
        FileUtils.rm(Vertebra::Daemon.pidfile) if File.exist?(Vertebra::Daemon.pidfile)
        logger.info "Stopped agent with PID #{pid}, signal #{sig}"
      rescue Errno::ENOENT
        logger.error "No pid file was found at #{Vertebra::Daemon.pidfile}"
      rescue Errno::EINVAL
        logger.error "Failed to kill PID #{pid}: '#{sig}' is an invalid or unsupported signal number."
      rescue Errno::EPERM
        logger.error "Failed to kill PID #{pid}: Insufficient permissions."
      rescue Errno::ESRCH
        logger.error "Failed to kill PID #{pid}: Process is deceased or zombie."
        FileUtils.rm pidfile
      rescue Exception => e
        logger.error "Failed to kill PID #{pid}: #{e.message}"
      end
    end

    def remove_pid_file
      FileUtils.rm(pidfile) if File.exist?(pidfile)
    end

    def setup_pidfile
      pid = Process.pid
      logger.info "Storing pid #{pid} in #{pidfile}"
      FileUtils.mkdir_p(File.dirname(pidfile)) unless File.directory?(File.dirname(pidfile))
      File.open(pidfile, 'w'){ |f| f.write("#{pid}") }
      at_exit { remove_pid_file }
    end

    def pidfile
      @config[:pid_path] || './agent.pid'
    end

    def change_privilege(user, group=user)
      logger.debug "Changing privileges to #{user}:#{group}"

      uid, gid = Process.euid, Process.egid
      target_uid = Etc.getpwnam(user).uid
      target_gid = Etc.getgrnam(group).gid

      if uid != target_uid || gid != target_gid
        # Change process ownership
        Process.initgroups(user, target_gid)
        Process::GID.change_privilege(target_gid)
        Process::UID.change_privilege(target_uid)
      end
    rescue Errno::EPERM => e
      logger.debug "Couldn't change user and group to #{user}:#{group}: #{e}"
    end

    def logger
      Vertebra.logger
    end
  end
end
