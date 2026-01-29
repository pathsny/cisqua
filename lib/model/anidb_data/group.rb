# An Identified Group that released a file with data from Anidb

require 'active_model'

module Cisqua
  class Group
    include Model::AnidbDataModelWithID
    include SemanticLogger::Loggable

    key_prefix :gid

    string_attrs :name, :short_name

    immutably_belongs_to :library
    has_many :anime_files, short_name: :files, short_id_name: :fids
    has_many :animes, redis_key_part: :anime, short_id_name: :aids, via: :anime_files
  end
end
