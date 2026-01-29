# Root record for Library

require 'active_model'

module Cisqua
  class Library
    include Model::Saveable
    include SemanticLogger::Loggable

    has_many :animes, short_id_name: :aids
    has_many :groups, short_id_name: :gids

    single_instance 'lib'

    def self.instance
      if find_if_exists.nil?
        new.update
      end
      find
    end
  end
end
