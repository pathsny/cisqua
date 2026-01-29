module Cisqua
  # This module indicates that a particular model can be serialized to
  # redis
  module Model
    module Redisable
      extend ActiveSupport::Concern
      class << self
        attr_accessor :db_provider
      end

      def db_provider
        Redisable.db_provider
      end

      class_methods do
        def db_provider
          Redisable.db_provider
        end
      end
    end
  end
end
