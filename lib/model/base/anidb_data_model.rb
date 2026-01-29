require_relative 'redisable'
require_relative 'saveable'
require_relative 'id_keyable'

module Cisqua
  module Model
    # Base class for models that are essentially derived from anidb
    # and hence act like a local cache of whats on Anidb
    module AnidbDataModel
      extend ActiveSupport::Concern
      include Saveable

      class_methods do
        def custom_api_transform(name, &block)
          @custom_api_transforms[name] = block
        end

        def from_api_response(transaction:, api_response:, **key_attrs)
          instance = find_by(**key_attrs) || new(**key_attrs)
          instance.assign_attributes(
            updated_at: Time.now,
            data_source: 'api_client',
          )

          api_attributes = api_response.each_with_object({}) do |(k, v), obj|
            if @custom_api_transforms.key?(k)
              transformed_value = @custom_api_transforms[k].nil? ? [] : @custom_api_transforms[k].call(v)
              instance.assign_attributes(transformed_value)
            else
              obj[k] = v
            end
          end
          model_attrs.update_from_api_response(instance, api_attributes)
          instance.save(transaction:)
        end
      end

      def expired?
        # we don't trust data if its not from the api client
        return true unless data_source == 'api_client'

        ttl = Registry.instance.options.api_client.cache.ttl
        expiry_time = updated_at + ttl
        now = Time.now
        expiry_time < now.tap do |expired|
          logger.debug 'checking expiry', ttl:, expiry_time:, now:, expired:
        end
      end

      included do
        string_attrs :data_source
        required_attrs :data_source
        @custom_api_transforms = {}
      end
    end
  end
end
