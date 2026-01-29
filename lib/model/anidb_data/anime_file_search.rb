# A search for an anime file by ed2k hash and size
#
# @attr [String] ed2k The ed2k hash of the file
# @attr [String] size The size of the file
# @attr [String] fid The file id of the file
# @attr [String] data_source Did this come from an API call or from a mylist import
# @attr [Time] updated_at When was this data last updated.
module Cisqua
  class AnimeFileSearch
    include Model::AnidbDataModel
    include SemanticLogger::Loggable

    string_attrs :ed2k, :size, :fid
    time_attrs :updated_at
    index_attrs :ed2k, :size
    attr_accessor :data_source

    has_one :anime_file, foreign_key: :fid, short_name: :file, one_way: true, can_be_nil: true

    def known?
      !fid.nil?
    end

    def self.make_key(ed2k, size)
      "ed2k:#{ed2k}:size:#{size}"
    end
  end
end
