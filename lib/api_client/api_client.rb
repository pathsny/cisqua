require 'fileutils'
require 'yaml'
module Cisqua
  require File.join(ROOT_FOLDER, 'net/ranidb')

  class APIClient
    include SemanticLogger::Loggable

    def initialize(client)
      @client = client
    end

    def process(_name, ed2k, size)
      @client.search_file(ed2k, size).tap do |info|
        logger.debug(
          'identified file',
          info:,
        )
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
      anime_info = info[:anime]
      logger.debug(
        'adding to mylist',
        name: anime_info[:romaji_name],
        epno: anime_info[:epno],
        group_name: anime_info[:group_name],
      )
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
end
