require 'mocha/api'
require 'rubygems'
require 'rspec'
require File.expand_path('../../lib/libs', __FILE__)

RSpec.configure do |rspec|
  rspec.mock_with :mocha
end


logger = create_logger('/dev/null')
