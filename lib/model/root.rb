# Root record

require 'active_model'
require_relative 'base/redisable'

module Cisqua
  class Root
    include Model::Saveable
    include SemanticLogger::Loggable

    int_attrs :version

    single_instance 'root'

    def self.update(**attrs)
      instance = find_if_exists || new(version: 1)
      instance.update(**attrs)
    end
  end
end
