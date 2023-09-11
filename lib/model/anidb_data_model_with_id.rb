require_relative 'redisable'
require_relative 'saveable'
require_relative 'id_keyable'

module Cisqua
  module Model
    # Base class for models that are essentially derived from anidb
    # and have an ID
    module AnidbDataModelWithID
      extend ActiveSupport::Concern
      include AnidbDataModel
      include IDKeyable
    end
  end
end
