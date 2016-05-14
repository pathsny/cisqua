require 'yaml'
Options = YAML.load_file(File.join(File.absolute_path(File.dirname(__FILE__)), '..', 'options.yml'))[:web]
Web_dir = File.absolute_path(File.dirname(__FILE__))

require 'rack'
require 'rack/contrib'
require 'rack/handler/puma'
require_relative 'app.rb'
ENV['RACK_ENV'] = 'deployment' unless ENV['RACK_ENV']

app = Rack::Builder.new do
  use Rack::CommonLogger
  use Rack::ShowExceptions

  map '/' do
    use Rack::PostBodyContentTypeParser
    run App
  end  
end


Rack::Handler::Puma.run app, :Host => Options[:bind], :Port => Options[:port]