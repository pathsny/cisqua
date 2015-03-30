require 'yaml'
Options = YAML.load_file(File.join(File.absolute_path(File.dirname(__FILE__)), '..', 'options.yml'))[:web]
Web_dir = File.absolute_path(File.dirname(__FILE__))

require 'rack'
require 'sprockets'
require 'sprockets/es6'
require 'rack/contrib'
require 'rack/handler/puma'
require_relative 'app.rb'

es6_processor = Sprockets::ES6.new('sourceMap' => 'inline')
Sprockets::ES6.instance_variable_set(:@instance, es6_processor)

app = Rack::Builder.new do
  use Rack::CommonLogger
  use Rack::ShowExceptions

  map '/assets' do
    env = Sprockets::Environment.new File.dirname(__FILE__)
    env.append_path 'js'
    env.append_path 'styles'
    env.append_path 'bower_components'
    env.append_path 'ext'
    run env
  end

  map '/' do
    use Rack::PostBodyContentTypeParser
    run App
  end  
end

ENV['RACK_ENV'] = 'deployment'

Rack::Handler::Puma.run app, :Host => Options[:bind], :Port => Options[:port]