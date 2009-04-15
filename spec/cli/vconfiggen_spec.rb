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
require 'vertebra/cli/vconfiggen'
require 'fileutils'

describe 'vconfiggen. The vertebra config generator' do

  vtempdir = "/tmp/vertebra_spec_vconfiggen_test_v_#{$$}"
  etempdir = "/tmp/vertebra_spec_vconfiggen_test_e_#{$$}"

  it 'vconfiggen smoketest' do
    Vertebra::CLI::VConfigGen.run(["--no-questions", "--vertebra-dir", vtempdir, "--ejabberd-dir", etempdir])

    contents = File.read("#{vtempdir}/agent.yml")
    contents.should match(/log_path:/)

    contents = File.read("#{etempdir}/ejabberd.cfg")
    contents.should match(/This config must be in UTF-8 encoding/)
  end

  # TODO: Write more tests, including tests that generate a single file.

  after(:all) do
    FileUtils.rm_rf(vtempdir)
    FileUtils.rm_rf(etempdir)
  end
end
