require 'active_model'

module Cisqua
  class TorrentHash
    include Model::Saveable
    include SemanticLogger::Loggable

    string_attrs :hash_string, :listed_torrent_id
    index_attrs :hash_string

    immutably_belongs_to :torrent, foreign_key: :listed_torrent_id, short_name: :listed_torrent, scope: :listed
    has_many :torrents, redis_key_part: :trs, scope: :all

    def self.make_key(hash_string)
      "th:#{hash_string}"
    end
  end
end
