require 'active_model'
require_relative 'redisable'

module Cisqua
  class Metadata
    include Model::IDKeyable
    include SemanticLogger::Loggable

    key_prefix :meta

    symbol_attrs :source, :image_status
    string_attrs :source_id
    hash_attrs :source_data

    def image_fetch_attempted?
      image_status == :fetched || image_status == :missing
    end

    def anime
      Anime.find(id)
    end
  end
end
