require_relative 'base_attribute'

module Cisqua
  module Model
    module Saveable
      module Attributes
        module TimeAttribute
          extend ActiveSupport::Concern

          class_methods do
            def time_attrs(*attrs)
              __add_attrs_to_list(
                attrs,
                Impl,
              )
            end
          end

          class Impl < PrimitiveImpl
            def valid_types
              Time
            end

            def from_redis(value)
              Time.at(value.to_i)
            end

            def to_redis(value)
              value.to_i.to_s
            end

            def from_api_response(value)
              Time.at(value.to_i)
            end
          end
        end
      end
    end
  end
end
