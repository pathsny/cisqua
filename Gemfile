ruby_version_path = File.join(File.expand_path(__dir__), '.ruby-version')
ruby File.read(ruby_version_path, mode: 'rb').chomp

source 'https://rubygems.org'

gem 'amazing_print'
gem 'invariant'
gem 'irb'
gem 'json'
gem 'logging'
gem 'rest-client'
gem 'semantic_logger'
gem 'solid_assert'

group :development do
  gem 'fakefs'
  gem 'faker'
  gem 'mocha'
  gem 'rspec'
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'solargraph'
end
