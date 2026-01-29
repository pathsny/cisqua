require 'active_model'

module Cisqua
  class Metadata
    include Model::IDKeyable
    include SemanticLogger::Loggable

    key_prefix :meta

    symbol_attrs :source, :image_status
    string_attrs :source_id
    hash_attrs :source_data

    immutably_belongs_to :anime, foreign_key: :id

    def image_fetch_attempted?
      image_status == :fetched || image_status == :missing
    end

    def has_image?
      image_status == :fetched
    end

    def image_url
      File.join(DATA_FOLDER, 'show_images', "a#{id}.jpg")
    end

    def image_file_exists?
      # probably not used in prod
      File.exist?(image_url)
    end
  end
end
