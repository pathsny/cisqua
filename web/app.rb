require 'json'
require_relative 'models.rb'
require_relative 'anidb_resource_fetcher.rb'
require 'bundler/setup'
require 'sinatra/base'
require 'tilt/erb'

# require 'rack/streaming_proxy'

class App < Sinatra::Application

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

  get "/anidb/:aid.xml" do
    content_type 'application/xml'
    send_file AnidbResourceFetcher.data(params[:aid])
  end

  get "/anidb/thumb/:aid.jpg" do
    content_type 'image/jpeg'
    send_file AnidbResourceFetcher.thumb(params[:aid])
  end  
end  
