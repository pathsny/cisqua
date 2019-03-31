ruby_version_path = File.join(File.expand_path('../', __FILE__), '.ruby-version')
ruby File.read(ruby_version_path, mode: 'rb').chomp

source 'https://rubygems.org'

gem 'sinatra'
gem 'json'
gem 'daybreak'
gem 'feedjira'
gem 'rack-contrib'
gem 'puma'
gem 'rack'
gem 'rest-client'
gem 'nokogiri'
gem 'invariant'
gem 'concurrent-ruby'
gem 'concurrent-ruby-ext'
gem 'concurrent-ruby-edge'
gem 'veto'
gem 'slowweb'
gem 'logging'
gem 'faye-websocket'
gem 'trans-api'
gem 'net-ping'

group :test do
  gem 'rspec'
  gem 'mocha'
  gem 'faker'
  gem 'fakefs'
  gem 'timecop'
end

group :development do
  gem 'rerun', '0.10.0'
  gem 'capistrano'
  gem 'capistrano-rsync-bladrak'
  gem 'capistrano-bundler'
  gem 'capistrano3-puma'
  gem 'capistrano-rbenv'
  gem 'capistrano-rbenv-install', '~> 1.2.0'
end
