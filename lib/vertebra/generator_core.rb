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

require 'erb'
require 'fileutils'
require 'find'

module GeneratorCore

  class NoSkeletonFound < Exception;end
  class NoDestinationFound < Exception;end
  class TemplateEvaluationFailed < Exception;end

  #####
  # generate_files(config = {})
  #
  # The config hash that is passed as an argument will be made available to
  # the erb templates.  It should also contain the following config items
  # which the generator requires in order to find the templates to work on and
  # to know where to put them.  There are also a couple optional generator
  # directives available.
  #
  #   :skeleton_dir -- This is the directory where the skeleton of erb templates
  #     that the generator is to operate on is found.  This must be provided or
  #     a GeneratorCore::NoSkeletonFound exception will be raised.
  #
  #   :destination_dir -- this is the directory that the generated files will
  #     be placed into.  This directory must either exist or be createable by
  #     the code, or a GeneratorCore::NoDestinationFound exception will be
  #     raised.
  #
  #   :verbose -- This is a true/false toggle that when true will cause the
  #     generator to output more information on exactly what steps it is taking
  #     as it processes the templates.
  #
  #   :noop -- This is a true/false toggle that when true will cause the
  #     generator to perform a dry run. That is, it will not actually write any
  #     of the generated files back to the filesystem.
  #
  #   :safe -- This is a true/false toggle that when true will prevent the
  #     generator from overwriting existing files.
  #
  #   :config_alias -- If this parameter is provided, then config hash will be
  #     aliased so that it is available under the variable name provided. This
  #     is here to provide flexibility to use semantically applicable naming
  #     inside the templates. i.e. in an actor generator, the config hash could
  #     be aliased to @actor.
  #
  #   :specific_files -- Generate only the specific files listed in the array
  #     passed in this option.
  #####

  def self.generate_files(config = {})
    file_utils_options = {}
    file_utils_options[:verbose] = config[:verbose]
    file_utils_options[:noop] = config[:dryrun]

    if config[:config_alias] and !(Array === config[:config_alias])
      config[:config_alias] = [config[:config_alias]]
    end

    skeleton_directory = File.expand_path("#{config[:skeleton_dir]}")
    raise NoSkeletonFound unless File.exist?(skeleton_directory)
    tmpdir = nil

    # If we are safe, and there are template files which would
    # overwrite existing files, the template files are first
    # renamed so that no conflict exists.
    if config[:safe] and FileTest.exist?(config[:destination_dir])
      tmpdir = "/tmp/generate_files_#{Time.now.to_i}_#{$$}"
      FileUtils.mkdir_p(tmpdir,file_utils_options.dup)
      FileUtils.cp_r("#{skeleton_directory}/.",tmpdir,file_utils_options.dup)

      stamp = Time.now.strftime('%Y%m%d%H%M%S')
      Find.find(config[:destination_dir]) do |__path|
        partial_path = __path.gsub(/^#{config[:destination_dir]}/,'')
        next if partial_path.empty?
        new_path = File.join(tmpdir, partial_path)
        if FileTest.exist?(new_path)
          renamed_new_path = "#{new_path}_#{stamp}"
          puts "Renaming conflicting file #{new_path} -> #{renamed_new_path}" if config[:verbose]
          FileUtils.mv(new_path,renamed_new_path,file_utils_options.dup)
        end
      end
    end

    begin
      FileUtils.mkdir_p(File.dirname(config[:destination_dir]),file_utils_options.dup) unless FileTest.exist? config[:destination_dir]
      if tmpdir
        if config[:specific_files]
          
          config[:specific_files].each do |f|
            FileUtils.cp_r(File.join(tmpdir,f),config[:destination_dir],file_utils_options.dup) if FileTest.exists? File.join(tmpdir,f)
          end
        else
          FileUtils.cp_r("#{tmpdir}/.",config[:destination_dir],file_utils_options.dup)
        end
      else
        if config[:specific_files]
          config[:specific_files].each do |f|
            FileUtils.cp_r(File.join(skeleton_directory,f),config[:destination_dir],file_utils_options.dup) if FileTest.exists? File.join(skeleton_directory,f)
          end
        else
          FileUtils.cp_r(skeleton_directory,config[:destination_dir],file_utils_options.dup)
        end
      end
    rescue Exception => e
      puts e.to_s
      puts e.backtrace.inspect
      raise NoDestinationFound.new(e)
    end

    unless config[:dryrun]
      if config[:config_alias]
        config[:config_alias].each do |var|
          next if var !~ /^@?\w+$/
          eval("#{var} = config",binding)
        end
      end

      # Two passes.  The first edits the files
      Find.find(config[:destination_dir]) do |__path|
        next unless FileTest.readable?(__path) and FileTest.file?(__path)
        template = ERB.new(File.read(__path))
        puts "Modifying #{__path}" if config[:verbose]
        begin
          File.open(__path,'w') do |fh|
            fh.write template.result(binding)
          end
        rescue Exception => e
          raise TemplateEvaluationFailed.new(e)
        end

      end

      # The second pass renames files/dirs.
      Find.find(config[:destination_dir]) do |__path|
        if __path =~ /__name__/
          FileUtils.mv(__path,__path.gsub(/__name__/,config[:name]),file_utils_options.dup)
          __path.gsub!(/__name__/,config[:name])
        end
      end

      FileUtils.rm_rf(tmpdir,file_utils_options.dup) if tmpdir
    end
  end

  def self.skeleton_dir(app, path = '')
    File.expand_path("#{File.dirname(__FILE__)}/../../skeleton/#{app}#{path}")
  end
end
