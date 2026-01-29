ruby_version_path = File.join(File.expand_path(__dir__), '.ruby-version')
ruby File.read(ruby_version_path, mode: 'rb').chomp

source 'https://rubygems.org'

gem 'actionview'
gem 'activemodel'
gem 'activesupport'
gem 'amazing_print'
gem 'connection_pool'
gem 'faraday'
gem 'json'
gem 'logging'
gem 'nokogiri'
gem 'pry'
gem 'rack-contrib'
gem 'redis'
gem 'semantic_logger'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'solid_assert'
gem 'thin'
gem 'transmission-rpc-ruby', github: 'pathsny/transmission-rpc-ruby'
gem 'tty-progressbar'

group :development, :test do
  gem 'erb-formatter'
  gem 'fakefs'
  gem 'faker'
  gem 'jsondiff'
  gem 'ld-eventsource'
  gem 'mocha'
  gem 'rb-fsevent'
  gem 'rerun'
  gem 'rspec'
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'rufo', require: false
end

group :deployment do
  gem 'bcrypt_pbkdf'
  gem 'ed25519'
  gem 'net-scp'
  gem 'net-ssh'
end
