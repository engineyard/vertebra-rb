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

module MockActor
  class Actor < Vertebra::Actor

    provides '/mock'

    bind_op "/list/numbers", :list_numbers
    desc "/list/numbers", "Get a list of numbers"
    def list_numbers(options = {})
      [1,2,3]
    end

    bind_op "/list/letters", :list_letters
    desc "/list/letters", "Get a list of letters"
    def list_letters(options = {})
      ['a', 'b', 'c']
    end

    bind_op "/list/slow", :list_slow
    desc "/list/slow", "Get a list of letters and numbers, slowly"
    def list_slow(options = {})
      size = options['size'].to_i
      size = 32 if size == 0

      lambda do |acc, n|
        acc << 'abcdef0123456789'[rand(16)].chr
        n -= 1
        sleep 1
        n == 0 ? acc : redo
      end.call('',size)
    end

    bind_op "/list/deferredslow", :list_deferred_slow
    desc "/list/deferredslow", "Get a list of letters and numbers, slowly, without blocking the reactor"
    def list_deferred_slow(options = {})
      bit = Vertebra::ActorSynapse.new(@agent)

      size = options['size'].to_i
      size = 32 if size == 0
      start = Time.now

      acc = ''
      bit.action do |synapse|
        if Time.now > (start + 1)
          start = Time.now
          acc << 'abcdef0123456789'[rand(16)].chr
          size -= 1
        end
        size == 0 ? acc : synapse
      end

      bit
    end

    bind_op "/list/deferredfast", :list_deferred_fast
    desc "/list/deferredfast", "Get a list of letters and numbers, quickly, a letter at a time, without blocking the reactor"
    def list_deferred_fast(options = {})
      bit = Vertebra::ActorSynapse.new(@agent)

      size = options['size'].to_i
      size = 32 if size == 0

      acc = ''
      bit.action do |synapse|
        acc << 'abcdef0123456789'[rand(16)].chr
        size -= 1
        size == 0 ? acc : synapse
      end

      bit
    end
    
    bind_op "/list/letters", :list_letters2
    desc "/list/letters2", "Get a list of letters; the list will be a given size, defaulting to 26, but alterable with a size option"
    def list_letters2(options = {})
      size = options['size'].to_i
      size = 26 if size == 0
      
      lambda do |acc, n| # This is a silly technique for something this simple, but it's kind cool.
        acc << ('a'..'z').to_a.join[rand(26)].chr
        n -= 1
        n == 0 ? acc : redo
      end.call('',size)
    end

    bind_op "/list/kaboom", :list_kaboom
    desc "/list/kaboom", "Doesn't actually do anything other than raise an exception"
    def list_kaboom(options = {})
      raise "Kaboom!"
    end
  end
end

