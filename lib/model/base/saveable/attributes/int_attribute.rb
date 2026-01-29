require_relative 'base_attribute'

module Cisqua
  module Model
    module Saveable
      module Attributes
        module IntAttribute
          extend ActiveSupport::Concern

          class_methods do
            def int_attrs(*attrs)
              __add_attrs_to_list(
                attrs,
                Impl,
              )
            end
          end

          class Impl < PrimitiveImpl
            def valid_types
              Integer
            end

            def from_redis(value)
              value.to_i
            end

            def to_redis(value)
              value.to_s
            end

            def from_api_response(value)
              value.to_i
            end
          end
        end
      end
    end
  end
end
