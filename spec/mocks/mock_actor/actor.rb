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
  end
end

