require 'active_model'
require_relative 'redisable'

module Cisqua
  class Group
    include Model::AnidbDataModelWithID
    include SemanticLogger::Loggable

    key_prefix :gid

    string_attrs :name, :short_name

    after_save :save_associations

    def fids
      redis.smembers("gid:#{id}:files")
    end

    def aids
      redis.smembers("gid:#{id}:anime")
    end

    def files
      fids.map { |fid| AnimeFile.find(fid) }
    end

    def animes
      aids.map { |aid| Anime.find(aid) }
    end

    def self.all_ids
      redis.smembers('groups')
    end

    def save_associations
      redis.sadd('groups', @id)
    end
  end
end
