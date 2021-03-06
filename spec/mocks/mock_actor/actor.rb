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

require File.dirname(__FILE__) + "/../../../lib/vertebra/actor"
require 'rubygems'
require 'thor'
require 'vertebra/actor_synapse'
require 'eventmachine'

class ProcessStreamer < EventMachine::Connection
  def initialize(cb)
    super()
    @cb = cb
    @closed = false
    @data = ''
  end

  def receive_data data
    @data << data
    rows = @data.split(/\n/)
    @data = rows.last
    @data << "\n" if data[-1] == 10

    rows[0..-2].each do |row|
      @cb.call(row)
    end
  end

  def unbind
    @data.split(/\n/).each { |row| @cb.call(row) }
    @closed = true
  end

  def closed?
    @closed
  end
end

module MockActor
  class Actor < Vertebra::Actor

    provides 'mock' => '/mock'

    bind_op "/list/numbers"
    desc "Get a list of numbers"
    def list_numbers(args)
      [1,2,3]
    end

    bind_op "/list/letters"
    desc "Get a list of letters"
    def list_letters(args)
      ['a', 'b', 'c']
    end

    bind_op "/list/slow"
    desc "Get a list of letters and numbers, slowly"
    def list_slow(args)
      size = args['size'].to_i
      size = 32 if size == 0

      lambda do |acc, n|
        acc << 'abcdef0123456789'[rand(16)].chr
        n -= 1
        sleep 1
        n == 0 ? acc : redo
      end.call('',size)
    end

    bind_op "/list/iostat"
    desc "Run 'iostat' and return the data, one line at a time, as it is available"
    def run_iostat(args, job)
      bit = Vertebra::ActorSynapse.new(@agent)

      interval = args['interval'] ? args['interval'].to_i : 1
      count = args['count'] ? args['count'].to_i : 5

      data_handler = lambda {|row| job.result row}
      streamer = EM.popen("iostat #{interval} #{count}",ProcessStreamer,data_handler)

      bit.action do |synapse|
        streamer.closed? ? nil : synapse
      end

      bit
    end

    bind_op "/list/deferredfast"
    desc "Get a list of letters and numbers, quickly, a letter at a time, without blocking the reactor"
    def deferred_fast(args)
      bit = Vertebra::ActorSynapse.new(@agent)

      size = args['size'].to_i
      size = 32 if size == 0

      acc = ''
      bit.action do |synapse|
        acc << 'abcdef0123456789'[rand(16)].chr
        size -= 1
        size == 0 ? acc : synapse
      end

      bit
    end

    bind_op "/list/somethingelse"
    desc "A proxy op that reissues another list op, based upon the arg it is given. ex. :as => 'numbers' "
    def somethingelse(args, job)
      as = args['as'] || 'numbers'
      op = "/list/#{as}"
      bit = Vertebra::ActorSynapse.new(@agent)

      bit.action do |synapse|
        unless bit[:requestor]
          bit[:requestor] = @agent.request(op, :all)
        end
        if bit[:requestor][:results]
          bit[:requestor][:results].each {|r| job.result r}
          nil
        else
          synapse
        end
      end

      bit
    end

    bind_op "/list/letters"
    desc "Get a list of letters; the list will be a given size, defaulting to 26, but alterable with a size option"
    def letters2(args)
      size = args['size'].to_i
      size = 26 if size == 0

      lambda do |acc, n| # This is a silly technique for something this simple, but it's kind cool.
        acc << ('a'..'z').to_a.join[rand(26)].chr
        n -= 1
        n == 0 ? acc : redo
      end.call('',size)
    end

    bind_op "/list/cipher"
    desc "Returns a hash of letters and numbers"
    def cipher(args)
      h = {}
      %w{ a b c d e f g h i j k l m n o p q r s t u v w x y z }.sort_by {rand}.each_with_index {|v,i| h[v] = i}
      h
    end

    bind_op "/list/kaboom"
    desc "Doesn't actually do anything other than raise an exception"
    def kaboom(args)
      raise "Kaboom!"
    end
  end
end

