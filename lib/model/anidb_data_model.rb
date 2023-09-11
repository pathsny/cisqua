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

      included do
        string_attrs :data_source
        other_required_attrs :data_source
      end

      def expired?
        # we don't trust data if its not from the api client
        return true unless data_source == 'api_client'

        logger.debug "comparing #{updated_at} and #{Registry.instance.options.api_client.cache.ttl} which is #{updated_at + Registry.instance.options.api_client.cache.ttl} vs #{Time.now}"
        updated_at + Registry.instance.options.api_client.cache.ttl < Time.now
      end

      class_methods do
        def custom_api_transform(name, &block)
          @custom_api_transforms[name] = block
        end

        def from_api_response(api_response, **key_attrs)
          attributes = api_response.each_with_object({}) do |(k, v), obj|
            if @custom_api_transforms.key?(k)
              transformed_value = @custom_api_transforms[k].nil? ? [] : @custom_api_transforms[k].call(v)
              transformed_value.each { |nk, nv| obj[nk] = nv }
              next
            end

            obj[k] = if bool_attr_list.include?(k)
              v == '1'
            elsif int_attr_list.include?(k)
              v.to_i
            elsif time_attr_list.include?(k)
              Time.at(v.to_i)
            elsif symbol_attr_list.include?(k)
              v.to_sym
            else
              assert(string_attr_list.include?(k), "unknown attribute type #{k} for #{name}")
              v
            end
          end
          new(attributes.merge(
            data_source: 'api_client',
            updated_at: Time.now,
            **key_attrs,
          ))
        end
      end
    end
  end
end
