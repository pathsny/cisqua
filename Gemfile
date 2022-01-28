ruby_version_path = File.join(File.expand_path('../', __FILE__), '.ruby-version')
ruby File.read(ruby_version_path, mode: 'rb').chomp

source 'https://rubygems.org'

gem 'json'
gem 'invariant'
gem 'logging'
gem 'amazing_print'
gem 'solid_assert'
gem 'irb'
gem 'rest-client'

group :test do
  gem 'rspec'
  gem 'mocha'
  gem 'faker'
  gem 'fakefs'
end

group :development do
  gem 'capistrano'
  gem 'capistrano-rsync-bladrak'
  gem 'capistrano-bundler'
  gem 'capistrano-rbenv'
  gem 'capistrano-rbenv-install', '~> 1.2.0'
end
