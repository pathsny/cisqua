require 'active_model'
require_relative 'redisable'

module Cisqua
  class Anime
    include Model::AnidbDataModelWithID
    include SemanticLogger::Loggable

    key_prefix :aid

    int_attrs :episode_count, :highest_episode_number, :special_ep_count
    bool_attrs :is_18_restricted
    time_attrs :air_date, :end_date
    string_attrs :dateflags, :year, :type, :romaji_name, :english_name

    after_save :save_associations
    before_save :detect_name_change

    custom_api_transform :episodes do |v|
      { episode_count: v.to_i }
    end

    def ended?
      dateflags.to_i[4] == 1
    end

    def movie?
      type == 'Movie'
    end

    def eids
      redis.smembers("aid:#{id}:episodes")
    end

    def episodes
      eids.map { |eid| Episode.find(eid) }
    end

    def fids
      episodes.flat_map(&:fids).uniq
    end

    def files
      fids.map { |fid| AnimeFile.find(fid) }
    end

    def gids
      redis.smembers("aid:#{id}:groups")
    end

    def groups
      gids.map { |gid| Group.find(gid) }
    end

    def metadata
      Metadata.find_by_id(id)
    end

    def self.all_ids
      redis.smembers('animes')
    end

    def save_associations
      redis.sadd('animes', @id)
    end

    def detect_name_change(saved_instance)
      return if saved_instance.nil? || saved_instance.romaji_name == romaji_name

      logger.warn('Anime name has changed', {
        id:,
        old_name: saved_instance.romaji_name,
        new_name: romaji_name,
      })
      MyList.update_anime_name(id, saved_instance.romaji_name, romaji_name)
    end
  end
end
