require 'active_model'
require_relative 'redisable'

module Cisqua
  class Episode
    include Model::AnidbDataModelWithID
    include SemanticLogger::Loggable

    key_prefix :eid

    time_attrs :aired
    string_attrs :aid, :length, :epno, :english_name,
      :romaji_name, :kanji_name

    after_save :save_associations

    custom_api_transform :rating
    custom_api_transform :votes

    def anime
      Anime.find(@aid)
    end

    def epno
      # if epno is a regular episode, we'll pad it with zeros
      int_val = Integer(@epno)
      required_length = anime.highest_episode_number.to_s.length
      int_val.to_s.rjust(required_length, '0')
    rescue ArgumentError
      @epno
    end

    def special_prefix
      result = /^(?<spc_type>[A-Z])?\d+$/.match(@epno)
      raise 'unknown' unless result

      result[:spc_type]
    end

    def special?
      !special_prefix.nil?
    end

    def name
      if english_name
        english_name
      elsif romaji_name
        romaji_name
      else
        kanji_name
      end
    end

    def fids
      redis.smembers("eid:#{id}:files")
    end

    def files
      fids.map { |fid| AnimeFile.find(fid) }.compact
    end

    def save_associations
      redis.sadd("aid:#{aid}:episodes", @id)
    end
  end
end
