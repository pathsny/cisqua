# An Identified Anime with data from Anidb
require 'active_model'
require_relative '../base/anidb_data_model_with_id'

module Cisqua
  class Anime
    include Model::AnidbDataModelWithID
    include SemanticLogger::Loggable

    key_prefix :aid

    int_attrs :episode_count, :highest_episode_number, :special_ep_count
    bool_attrs :is_18_restricted
    time_attrs :air_date, :end_date
    string_attrs :dateflags, :year, :type, :romaji_name, :english_name

    has_one :metadata, foreign_key: :id, can_be_nil: true
    has_many :episodes, short_id_name: :eids
    has_many :anime_files, short_name: :files, short_id_name: :fids, through: :episode
    has_many :groups, short_id_name: :gids, via: :anime_files
    immutably_belongs_to :library

    on_save :detect_name_change
    after_save :move_files_if_name_changed

    custom_api_transform :episodes do |v|
      { episode_count: v.to_i }
    end

    def ended?
      dateflags.to_i[4] == 1
    end

    def movie?
      type == 'Movie'
    end

    def metadata
      Metadata.find_by_id(id)
    end

    def likely_episode_count
      return episode_count.to_i if episode_count.to_i.positive?

      highest_episode_number.to_i
    end

    def detect_name_change(operation, transaction)
      return unless operation == :update && romaji_name_changed?

      logger.warn('Anime name has changed', {
        id:,
        old_name: romaji_name_was,
        new_name: romaji_name,
      })
      MyList.instance.update_anime_name(id, romaji_name_was, romaji_name, transaction:)
      BatchProcessor.instance.record_anime_name_change(id, romaji_name_was, romaji_name, transaction:)
    end

    def move_files_if_name_changed(operation)
      return unless operation == :update

      if romaji_name_previously_changed?
        Registry.instance.renamer.process_name_change(self)
      end
    end
  end
end
