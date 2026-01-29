# A snapshot of the Mylist data for an anime associated with a batch of files.
#
# @attr [String] aid The Anime for which this mylist snapshot is captured
# @attr [String] batch_data_id The batch of files this raw file was a part of.
# @attr [String] index The index of this snapshot in the batch. Ordering is
#                   based on the first time a file of this anime was processed.

require 'active_model'

module Cisqua
  class MylistAnimeSnapshot
    include Model::Saveable
    include SemanticLogger::Loggable

    string_attrs :aid, :batch_data_id
    int_attrs :index
    index_attrs :batch_data_id, :aid

    immutably_belongs_to :anime, foreign_key: :aid, one_way: true
    immutably_belongs_to :batch_data, foreign_key: :batch_data_id, id_attribute: :aid
    has_many :anime_files, short_name: :files, short_id_name: :fids, one_way: true

    def self.make_key(batch_data_id, aid)
      "bd:#{batch_data_id}:sn:#{aid}"
    end

    def self.capture_mylist_data(aid:, transaction: nil, **attrs)
      instance = new(aid:, **attrs)

      db_provider.write(transaction:) do |t|
        instance.update(transaction: t)
        instance.fids.add_many(
          transaction: t,
          ids: MyList.instance.entries[aid]&.fids || [],
        )
      end
    end
  end
end
