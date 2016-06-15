require 'json'
require_relative 'lib/constants'
require_relative 'model/all_models.rb'
require_relative 'lib/anidb_resource_fetcher.rb'
require_relative 'lib/feed_processor'
require_relative '../lib/loggers.rb'
require_relative '../lib/concurrent_logger.rb'
require 'bundler/setup'
require 'sinatra/base'
require 'tilt/erb'

def Logging.make_sinatra_logger
  Loggers::Web.tap do |l|
    def l.write(resp)
      offset = resp.index('"')
      self.info resp.slice(offset, resp.length - offset)
    end  
  end
end

class ErrorLogger
  class << self
    def puts(msg)
      Loggers::Web.error msg
    end
  end    
end

class App < Sinatra::Application
  configure do
    disable :logging
    use Rack::CommonLogger, Logging.make_sinatra_logger
  end

  before { env["rack.errors"] =  ErrorLogger }  

  set :root, File.dirname(__FILE__)
  set :static_cache_control, [:no_cache, :must_revalidate, max_age: 0]

  before do
    content_type 'application/json'
  end

  get "/" do
    redirect '/index.html'
  end

  get "/shows" do
    {
      is_updating_feed_items: FeedProcessor.is_updating_feed_items?, 
      shows: Show.all,
    }.to_json
  end

  get "/shows/with_feed_items" do
    {
      is_updating_feed_items: FeedProcessor.is_updating_feed_items?, 
      shows: Show.all.map(&:to_hash_for_json_with_feed_items),
    }.to_json
  end

  get "/shows/:id" do
    Show.exists?(params[:id]) ? Show.get(params[:id]).to_json : not_found
  end

  get "/shows/:id/with_feed_items" do
    Show.exists?(params[:id]) ? 
      Show.get(params[:id]).to_json_with_feed_items : 
      not_found
  end

  post "/shows/new" do
    begin
      show = Show.create(*[:id, :name, :feed_url, :auto_fetch].map{|sym|params[sym]})
      show.save
      redirect "/shows/#{params[:id]}"
    rescue Veto::InvalidEntity => e
      [400, show.errors.to_json]
    end  
  end

  post "/shows/new/with_feed_items" do
    begin
      show = Show.create(*[:id, :name, :feed_url, :auto_fetch].map{|sym|params[sym]})
      show.save
      redirect "/shows/#{params[:id]}/with_feed_items"
    rescue Veto::InvalidEntity => e
      [400, show.errors.to_json]
    end  
  end

  delete "/shows/:id" do
    show = Show.get(params[:id])
    show.destroy!
    200
  end  

  # put "/shows/:id" do
  #   @show = Show.get params[:id]
  #   @show.aid = params[:aid]
  #   show.save.to_json
  # end

  get "/anidb/:aid.xml" do
    content_type 'application/xml'
    send_file AnidbResourceFetcher.data(params[:aid])
  end

  get "/anidb/thumb/:aid.jpg" do
    content_type 'image/jpeg'
    send_file AnidbResourceFetcher.thumb(params[:aid])
  end

  post "/force/check_feeds" do
    FeedProcessor.update_all_shows
    200
  end  

  post "/force/check_feed/:id" do
    Show.exists?(params[:id]) ? FeedProcessor.update_show(params[:id]) : not_found
  end  
end  
