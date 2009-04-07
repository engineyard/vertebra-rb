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

require File.dirname(__FILE__) + '/spec_helper'

module SpecActors
  class Numbers < Vertebra::Actor
    provides 'mock' => '/mock'

    bind_op '/list/numbers'
    desc 'List some numbers'
    def array_of_numbers(operations, args)
      args['alternate'] ? [2,3,4] : [1,2,3]
    end
  end

  class TwoResourcesForSameKey < Vertebra::Actor
    provides 'color' => '/color/red'
    provides 'color' => '/color/blue'
  end

  class Taunt < Vertebra::Actor
    provides 'test' => '/awesome/1'
    provides 'test' => '/awesome/2'

    bind_op '/mock/num'
    bind_op '/mock/num2'
    desc "Send a number back"
    def num(operation, args)
      {"result" => 1}
    end

    bind_op '/mockery/taunt'
    desc "Send a taunt"
    def taunt(operation, args)
      {"message" => "$UNORIGINAL_COMMENT"}
    end
  end
end

describe Vertebra::Actor do
  include Vertebra::Utils

  before(:each) do
    deployment = Vertebra::KeyedResources.new
    deployment.add("cluster", '/cluster/rd00')
    deployment.add("node", '/node/1')
    @numbers = SpecActors::Numbers.new(nil, deployment, {})
    @taunt = SpecActors::Taunt.new(nil, deployment, nil)
  end

  it 'merges development and deploment resources' do
    @numbers.should provide_resources(
      'cluster' => ['/cluster/rd00'],
      'node' => ['/node/1'],
      'mock' => ['/mock']
    )
  end

  it 'allows multiple resources with the same key' do
    SpecActors::TwoResourcesForSameKey.should provide_resources(
      "color" => ["/color/blue", "/color/red"]
    )
  end

  it 'stores the provided operations' do
    SpecActors::Taunt.should provide_operations(["/mock/num", "/mock/num2", "/mockery/taunt"])
  end

  it "provides the operation" do
    @taunt.should be_providing_operation(resource('/mock'))
    @taunt.should be_providing_operation(resource('/mock/num'))
    @taunt.should be_providing_operation(resource('/mock/num/test'))
    @taunt.should be_providing_operation(resource('/mockery/taunt'))
  end

  it "does not provide the operation" do
    @taunt.should_not be_providing_operation(resource('/mock2/test'))
  end

  it 'provides the resources' do
    @taunt.should be_providing_resources("test" => resource('/'))
    @taunt.should be_providing_resources("test" => resource('/awesome'))
    @taunt.should be_providing_resources("test" => resource('/awesome/1'))
  end

  it 'does not provide the resources' do
    @taunt.should_not be_providing_resources("test" => resource('/missing'))
  end
end
