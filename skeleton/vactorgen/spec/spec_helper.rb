# This is generated code.  You should replace this with a copyright statement
# and licensing information.

$TESTING=true
$:.push File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'rr'
require 'spec'

Spec::Runner.configure do |config|
  config.mock_with :rr
  # or if that doesn't work due to a version incompatibility
  # config.mock_with RR::Adapters::Rspec
end
