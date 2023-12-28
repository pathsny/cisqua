require 'active_model'
require_relative 'redisable'

module Cisqua
  class MetadataTokens
    include Model::Saveable
    include SemanticLogger::Loggable
    string_attrs :tvdb_token, :mapping_etag, :tmdb_access_token
    unique_attrs

    def self.token(type)
      tokens = find_if_exists
      return nil unless tokens

      case type
      when :tvdb
        tokens.tvdb_token
      when :tmdb
        tokens.tmdb_access_token
      end
    end

    def self.find_if_exists
      find_by_
    end

    def self.make_key
      'metadata_tokens'
    end

    def self.update_instance(attrs)
      instance = find_if_exists || new
      attrs[:updated_at] = Time.now
      instance.update(attrs)
    end
  end
end
