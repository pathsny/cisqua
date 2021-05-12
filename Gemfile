ruby_version_path = File.join(File.expand_path('../', __FILE__), '.ruby-version')
ruby File.read(ruby_version_path, mode: 'rb').chomp

source 'https://rubygems.org'

gem 'json'
gem 'puma'
gem 'rest-client'
gem 'nokogiri'
gem 'invariant'
gem 'logging'
gem 'amazing_print'
gem 'solid_assert'

group :test do
  gem 'rspec'
  gem 'mocha'
  gem 'faker'
  gem 'fakefs'
  gem 'timecop'
end

group :development do
  gem 'rerun', '0.10.0'
  gem 'irb'
  gem 'capistrano'
  gem 'capistrano-rsync-bladrak'
  gem 'ed25519'
  gem 'bcrypt_pbkdf'
  gem 'capistrano-bundler'
  gem 'capistrano-rbenv'
  gem 'capistrano-rbenv-install', '~> 1.2.0'
end
