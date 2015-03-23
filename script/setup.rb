#!/usr/bin/env ruby
require 'fileutils'
root_dir = File.join(File.dirname(__FILE__), '..')
FileUtils.mkdir_p(File.join(root_dir, 'data'))

Dir.chdir(root_dir) {
  raise "could not run bundler" unless system "bundle install"
}

if ARGV[0] == 'dev' then
  Dir.chdir(File.join(root_dir, 'web')) {
    raise "could not run bower" unless system "bower install"
  }
end

