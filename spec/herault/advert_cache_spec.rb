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

require File.dirname(__FILE__) + '/../spec_helper'

require 'vertebra/herault/advert_cache'

describe Vertebra::Herault::AdvertCache do
  include Vertebra::Utils

  def ordered(resources)
    resources.sort_by do |r|
      r.parts
    end
  end

  before(:each) do
    @cache = Vertebra::Herault::AdvertCache.new
  end

  it "starts with no resources" do
    @cache.resources.should be_empty
  end

  it "can add 1-level resources" do
    @cache.add(resource("/test"), "test@localhost/agent", 10)
    @cache.resources.should == [resource("/test")]
  end

  it "can add multi-level resources" do
    @cache.add(resource("/test/resource"), "test@localhost/agent", 10)
    @cache.resources.should == [resource("/test/resource")]
  end

  it "can add more than one multi-level resource" do
    @cache.add(resource("/test/resource"), "test@localhost/agent", 10)
    @cache.add(resource("/test2/resource"), "test@localhost/agent", 10)
    ordered(@cache.resources).should == [resource("/test/resource"), resource("/test2/resource")]
  end

  it "can add more than one mixed-level resource" do
    @cache.add(resource("/test"), "test@localhost/agent", 10)
    @cache.add(resource("/test2/resource"), "test@localhost/agent", 10)
    @cache.add(resource("/test3/resource/pass"), "test@localhost/agent", 10)
    ordered(@cache.resources).should == [resource("/test"), resource("/test2/resource"), resource("/test3/resource/pass")]
  end

  it "can add more than one overlapping mixed-level resource" do
    @cache.add(resource("/test"), "test@localhost/agent", 10)
    @cache.add(resource("/test/resource"), "test@localhost/agent", 10)
    @cache.add(resource("/test/resource/pass"), "test@localhost/agent", 10)
    ordered(@cache.resources).should == [resource("/test"), resource("/test/resource"), resource("/test/resource/pass")]
  end

  describe "with resources added" do
    before(:each) do
      @cache.add(resource("/test"), "1", 10)
      @cache.add(resource("/test/resource"), "2", 10)
      @cache.add(resource("/test/resource/pass"), "3", 10)
      @cache.add(resource("/test2/resource/login"), "4", 10)
    end

    it "has jids" do
      @cache.jids.sort.should == %w{ 1 2 3 4 }
    end

    it "finds all resources" do
      @cache.search(resource("/")).sort.should == %w{ 1 2 3 4 }
    end

    it "finds resources" do
      @cache.search(resource("/test")).sort.should == %w{ 1 2 3 }
    end

    it "finds all resources for a specific query" do
      @cache.search(resource("/test/resource/pass")).sort.should == %w{ 1 2 3 }
    end

    it "finds a specific resource" do
      @cache.search(resource("/test2/resource/login")).sort.should == %w{ 4 }
    end
  end

  describe "with multiple resources announced by the same jids" do
    before(:each) do
      @cache.add(resource("/test/resource"), "1", 10)
      @cache.add(resource("/test/resource/pass"), "2", 10)
      @cache.add(resource("/test/resource/pass"), "1", 10)
      @cache.add(resource("/test/resource/pass2"), "2", 10)
      @cache.add(resource("/test2"), "1", 10)
      @cache.add(resource("/test2/resource/pass"), "3", 10)
      @cache.add(resource("/test2/resource/pass2"), "2", 10)
      @cache.add(resource("/otherstuff"), "4", 100)
    end

    it "finds all resources" do
      @cache.search(resource("/")).sort.should == %w{ 1 2 3 4 }
    end

    it "finds resources" do
      @cache.search(resource("/test")).sort.should == %w{ 1 2 }
    end

    it "finds resources 2" do
      @cache.search(resource("/test2")).sort.should == %w{ 1 2 3 }
    end

    it "finds a specific resource" do
      @cache.search(resource("/test/resource/pass")).sort.should == %w{ 1 2 }
    end

    it "finds a specific resource 2" do
      @cache.search(resource("/otherstuff")).sort.should == %w{ 4 }
    end

    it "finds an unadvertised descendent of an advertised resource" do
      @cache.search(resource("/test2/letters")).sort.should == %w{ 1 }
    end
  end
end
