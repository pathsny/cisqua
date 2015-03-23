require 'yaml'
require 'json'
Options = YAML.load_file(File.join(File.absolute_path(File.dirname(__FILE__)), '..', 'options.yml'))[:web]
require File.join(File.absolute_path(File.dirname(__FILE__)), 'models.rb')
require 'bundler/setup'
require 'sinatra'
require 'tilt/erb'
require 'rack/contrib'
# require 'rack/streaming_proxy'

use Rack::PostBodyContentTypeParser
# use Rack::StreamingProxy::Proxy do |request|
#   if request.path.start_with?('/remote/')
#     path = request.path.sub(%r{^/remote/}, '')
#     "http://#{path}?#{request.query_string}"
#   end
# end

set :port, Options[:port]
set :bind, '0.0.0.0'
set :public_folder, File.dirname(__FILE__)
set :environment, Options[:environment]
set :server, :puma

before do
    content_type 'application/json'
end

get "/" do
  content_type 'html'
  erb :index
end

get "/shows" do
  Show.all.to_json
end

post "/shows/new" do
  @show = Show.new(params[:aid], params[:name])
  @show.created_at = DateTime.now
  @show.save.to_json
end

# put "/shows/:id" do
#   @show = Show.get params[:id]
#   @show.aid = params[:aid]
#   show.save.to_json
# end

delete "/shows/:aid" do
  @show = Show.get params[:aid]
  @show.destroy.to_json
end