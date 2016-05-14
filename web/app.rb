require 'json'
require_relative 'models.rb'
require_relative 'anidb_resource_fetcher.rb'
require 'bundler/setup'
require 'sinatra/base'
require 'tilt/erb'

class App < Sinatra::Application

  set :static_cache_control, [:no_cache, :must_revalidate, max_age: 0]

  before do
      content_type 'application/json'
  end

  get "/" do
    content_type 'html'
    erb :index, :locals => {:production => self.class.production?}
  end

  get "/shows/:id" do
    Show.exists?(params[:id]) ? Show.get(params[:id]) : not_found
  end

  get "/shows" do
    Show.all.to_json
  end

  post "/shows/new" do
    @show = Show.new(params[:id], params[:name], params[:feed])
    @show.created_at = DateTime.now
    @show.save.to_json
  end

  # put "/shows/:id" do
  #   @show = Show.get params[:id]
  #   @show.aid = params[:aid]
  #   show.save.to_json
  # end

  delete "/shows/:id" do
    @show = Show.get params[:id]
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
