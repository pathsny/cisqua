module Cisqua
  # This module indicates that a particular model can be serialized to
  # redis
  module Model
    module Redisable
      extend ActiveSupport::Concern
      class << self
        attr_accessor :redis
      end

      def redis
        Redisable.redis
      end

      class_methods do
        def redis
          Redisable.redis
        end
      end
    end
  end
end
