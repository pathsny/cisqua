#!/usr/bin/env ruby

require 'fileutils'
root_dir = File.join(File.dirname(__FILE__), '..')
data_dir = File.join(root_dir, 'data')
options_file = File.join(data_dir, 'options.yml')
db_dir = File.join(data_dir, 'db')
http_cache_dir = File.join(data_dir, 'http_anime_info_cache')
http_cache_lock_dir = File.join(data_dir, 'http_anime_info_cache/lock')
log_dir = File.join(root_dir, 'log')

FileUtils.mkdir_p(data_dir)
FileUtils.mkdir_p(db_dir)
FileUtils.mkdir_p(http_cache_dir)
FileUtils.mkdir_p(http_cache_lock_dir)
FileUtils.mkdir(log_dir)

FileUtils.cp(File.join(root_dir, 'script/helpers/options.yml.bak'), options_file) unless File.exist?(options_file)

Dir.chdir(root_dir) do
  raise 'could not run bundler' unless system 'bundle install'
end

# How to start redis
# redis-server
