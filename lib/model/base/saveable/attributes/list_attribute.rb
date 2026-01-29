require_relative 'base_attribute'

module Cisqua
  module Model
    module Saveable
      module Attributes
        module ListAttribute
          extend ActiveSupport::Concern

          class_methods do
            def list_attrs(*attrs)
              __add_attrs_to_list(
                attrs,
                Impl,
              )
            end
          end

          class Impl < SerializedImpl
            def valid_types
              Array
            end

            def from_redis(value)
              JSON.parse(value)
            end

            def to_redis(value)
              value.to_json
            end
          end
        end
      end
    end
  end
end
