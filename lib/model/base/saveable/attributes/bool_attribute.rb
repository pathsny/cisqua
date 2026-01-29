require_relative 'base_attribute'

module Cisqua
  module Model
    module Saveable
      module Attributes
        module BoolAttribute
          extend ActiveSupport::Concern

          class_methods do
            def bool_attrs(*attrs)
              __add_attrs_to_list(
                attrs,
                Impl,
              )
            end
          end

          class Impl < PrimitiveImpl
            def valid_types
              [TrueClass, FalseClass]
            end

            def from_redis(value)
              value == 'true'
            end

            def to_redis(value)
              value.to_s
            end

            def from_api_response(value)
              value == '1'
            end
          end
        end
      end
    end
  end
end
