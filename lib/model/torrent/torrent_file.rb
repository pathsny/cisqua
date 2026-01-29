require 'active_model'

module Cisqua
  class TorrentFile
    include Model::Saveable
    include SemanticLogger::Loggable

    string_attrs :name, :torrent_id
    int_attrs :length, :bytes_completed, :priority, :index
    index_attrs :torrent_id, :index
    bool_attrs :wanted

    immutably_belongs_to :torrent, foreign_key: :torrent_id, id_attribute: :index

    def completed?
      bytes_completed == length
    end

    def self.upsert_from_api_response_if_changed(torrent_hash_string:, file_data:, file_stat_data:, transaction: nil)
      name = file_data['name']
      torrent_file =
        find_by_torrent_hash_string_and_name(torrent_hash_string, name) ||
        new(torrent_hash_string:, name:)
      torrent_file.assign_attributes(
        length: file_data['length'],
        bytes_completed: file_data['bytesCompleted'],
        priority: file_stat_data['priority'],
        wanted: file_stat_data['wanted'],
      )
      return nil unless torrent_file.changed?

      db_provider.write(transaction:) do |t|
        torrent_file.update(transaction: t)
      end
    end

    def self.make_key(torrent_hash_string, name)
      "tf:#{torrent_hash_string}:#{name}"
    end
  end
end
