require_relative 'base_attribute'

module Cisqua
  module Model
    module Saveable
      module Attributes
        module FloatAttribute
          extend ActiveSupport::Concern

          class_methods do
            def float_attrs(*attrs)
              __add_attrs_to_list(
                attrs,
                Impl,
              )
            end
          end

          class Impl < PrimitiveImpl
            def valid_types
              Float
            end

            def from_redis(value)
              value.to_f
            end

            def to_redis(value)
              value.to_s
            end

            def from_api_response(value)
              value.to_f
            end
          end
        end
      end
    end
  end
end
