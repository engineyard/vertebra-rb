require 'rubygems'
require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'
require 'rake/testtask'
require "spec/rake/spectask"

GEM = "vertebra"
GEM_VERSION = "0.4.0"
AUTHOR = "Engine Yard, Inc."
EMAIL = "vertebra-dev@googlegroups.com"
HOMEPAGE = "http://vertebra.engineyard.com"
SUMMARY = "XMPP framework for autonomous agents"

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README", "LICENSE", "TODO"]
  s.summary = SUMMARY
  s.description = s.summary
  s.author = AUTHOR
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.rubyforge_project = GEM

  s.executables = Dir.entries('bin').reject {|x| /^\.+$/.match x}
  s.add_dependency "rr"
  s.add_dependency "open4"
  s.add_dependency "thor"

  s.require_path = 'lib'
  s.files = %w(LICENSE README Rakefile TODO) + Dir.glob("{config,lib,spec,vendor,skeleton}/**/*")
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Run unit specs"
Spec::Rake::SpecTask.new("unit") do |t|
  t.spec_opts = ["--format", "specdoc", "--colour"]
  t.spec_files = FileList["spec/**/*_spec.rb"]
end

desc "Run all specs with bacon"
task :bacon do
  sh "bacon #{Dir["spec/**/*_spec.rb"].join(" ")}"
end

desc "install the gem locally"
task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{GEM_VERSION} --no-update-sources}
end

desc "uninstall the gem locally"
task :uninstall => [:package] do
  sh %{sudo gem uninstall #{GEM} -v #{GEM_VERSION} -I -x}
end

desc "create a gemspec file"
task :make_spec do
  File.open("#{GEM}.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end

desc "get help"
task :default do
  output = `rake -T`
  puts output.split("\n")[1..-1].join("\n")
end
