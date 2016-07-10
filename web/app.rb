require 'json'
require 'uri'
require 'bundler/setup'
require 'sinatra/base'
require 'tilt/erb'

require_relative '../lib/options'
require_relative 'lib/constants'
require_relative 'lib/bootstrap'
require_relative 'model/all_models'
require_relative 'lib/anidb_http'
require_relative 'lib/feed_processor'
require_relative 'lib/torrent'
require_relative '../lib/loggers'
require_relative '../lib/concurrent_logger'

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

  def favicon_path
    "favicon.#{settings.environment}.ico"
  end  

  before do
    content_type 'application/json'
    env["rack.errors"] =  ErrorLogger
  end

  get "/favicon.ico" do
    content_type 'image/x-icon'
    send_file File.join(settings.root, 'public', favicon_path), :disposition => :inline
  end  

  get "/" do
    content_type 'text/html'
    erb :index
  end

  get "/logs" do
    content_type 'text/html'
    erb :index
  end

  get "/settings" do
    content_type 'text/html'
    erb :index
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

  # put "/shows/:id" do
  #   @show = Show.get params[:id]
  #   @show.aid = params[:aid]
  #   show.save.to_json
  # end

  delete "/shows/:id" do
    show = Show.get(params[:id])
    show.destroy!
    200
  end

  # instead of using feed_items/:item_id, we expect id to be a query string param
  # the reason for this is some feed_item ids cannot be used inside a url since 
  # they are urls 
  get "/shows/:show_id/feed_item" do
    return not_found unless Show.exists?(params[:show_id])
    feed = Show.get(params[:show_id]).feed
    feed.exists?(params[:id]) ? feed.get(params[:id]).to_json : not_found
  end

  post "/shows/:show_id/feed_item/download" do
    feed_item = Show.get(params[:show_id]).feed.get(params[:id])
    Torrent.download feed_item
    redirect "/shows/#{params[:show_id]}/feed_item?id=#{CGI.escape(params[:id])}" 
  end  

  post "/shows/:show_id/feed_item/mark_downloaded" do
    feed_item = Show.get(params[:show_id]).feed.get(params[:id])
    feed_item.mark_downloaded
    redirect "/shows/#{params[:show_id]}/feed_item?id=#{CGI.escape(params[:id])}"
  end

  post "/shows/:show_id/feed_item/unmark_downloaded" do
    feed_item = Show.get(params[:show_id]).feed.get(params[:id])
    feed_item.unmark_downloaded
    redirect "/shows/#{params[:show_id]}/feed_item?id=#{CGI.escape(params[:id])}"
  end

  get "/anidb/:aid.xml" do
    content_type 'application/xml'
    send_file AnidbHTTP.data(params[:aid])
  end

  get "/anidb/thumb/:aid.jpg" do
    content_type 'image/jpeg'
    send_file AnidbHTTP.thumb(params[:aid])
  end

  post "/force/check_feeds" do
    FeedProcessor.update_all_shows
    200
  end  

  post "/force/check_feed/:id" do
    Show.exists?(params[:id]) ? FeedProcessor.update_show(params[:id]) : not_found
  end

  get "/settings/values" do
    Options.values.to_json
  end

  post "/settings/values/:name" do
    begin
      Options.save(params[:name], params)
      200
    rescue Veto::InvalidEntity => e
      [400, e.errors.to_json]
    end  
  end  
end  
