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

require 'fileutils'

describe 'vactorgen. The vertebra actor generator' do
  
  tempdir = "/tmp/vertebra_spec_vactorgen_test_#{$$}"

  it 'vactorgen smoketest' do
    command = "#{File.dirname(__FILE__)}/../bin/vactorgen --no-questions -n testactor -c TestActor #{tempdir}"
    system(command)

    contents = File.read("#{tempdir}/lib/testactor/actor.rb")
    contents.should match(/module\s+TestActor/)
  end

  # TODO: Write more tests, including tests that generate single files.

  after(:all) do
    FileUtils::rm_rf(tempdir)
  end

end
