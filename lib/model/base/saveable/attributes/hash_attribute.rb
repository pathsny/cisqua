require_relative 'base_attribute'

module Cisqua
  module Model
    module Saveable
      module Attributes
        module HashAttribute
          extend ActiveSupport::Concern

          class_methods do
            def hash_attrs(*attrs)
              __add_attrs_to_list(
                attrs,
                Impl,
              )
            end
          end

          class Impl < SerializedImpl
            def valid_types
              Hash
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
