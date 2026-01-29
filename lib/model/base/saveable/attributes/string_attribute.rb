require_relative 'base_attribute'

module Cisqua
  module Model
    module Saveable
      module Attributes
        module StringAttribute
          extend ActiveSupport::Concern

          class_methods do
            def string_attrs(*attrs, **)
              __add_attrs_to_list(
                attrs,
                Impl,
                **,
              )
            end
          end

          class Impl < PrimitiveImpl
            def valid_types
              String
            end

            def from_redis(value)
              value
            end

            def to_redis(value)
              value
            end

            def from_api_response(value)
              value.to_s
            end
          end
        end
      end
    end
  end
end
