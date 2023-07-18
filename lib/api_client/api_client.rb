require 'yaml'
require 'fileutils'
require File.join(ROOT_FOLDER, 'net/ranidb')

class APIClient

  def initialize(api_options, test_mode)
    @client = ProxyClient.new(api_options, test_mode)
  end

  def process(name, ed2k, size)
    @client.search_file(ed2k, size).tap do |info|
      Loggers::PostProcessor.debug "file #{name} identified as #{info.inspect}"
      return nil if info.nil?

      update_mylist_with info
      aid = info[:file][:aid]
      info[:anime].merge! retrieve_show_details(aid)[:anime]
      info[:anime][:completed] = fetch_mylist_data(aid, info[:anime][:episodes]).tap do |m|
        m.add info[:anime][:epno]
      end.complete?
    end
  end

  def disconnect
    @client.disconnect
  end

  private

  def update_mylist_with(info)
    Loggers::PostProcessor.debug "adding #{info.inspect} to mylist"
    @client.mylist_add(info[:fid])
  end

  def retrieve_show_details(aid)
    @client.anime(aid)
  end

  def fetch_mylist_data(aid, episodes)
    mylist_hash = @client.mylist_by_aid(aid)[:mylist]
    mylist_hash[:epno] = fetch_episode_no(mylist_hash[:eid]) if mylist_hash[:single_episode]
    MylistData.new(episodes.to_i, mylist_hash)
  end

  def fetch_episode_no(eid)
    @client.episode(eid)[:episode][:epno]
  end
end
