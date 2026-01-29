module Cisqua
  module Model
    module Saveable
      module Attributes
        module BaseAttribute
          extend ActiveSupport::Concern

          class_methods do
            def __add_attrs_to_list(attrs, attr_klass, read_only: false)
              model_attrs.add(attr_klass, attrs)
              attrs.each do |attr|
                define_method(attr) do
                  instance_variable_get("@#{attr}")
                end

                next if read_only

                define_method("#{attr}=") do |value|
                  current_value = instance_variable_get("@#{attr}")
                  send("#{attr}_will_change!") unless value == current_value
                  instance_variable_set("@#{attr}", value)
                end
              end
              define_attribute_methods(*attrs)
            end
          end

          included do
            class_attribute :model_attrs
            self.model_attrs = AttributeCollection.new
          end
        end

        class BaseImpl
          include SemanticLogger::Loggable
          attr_accessor :required
          attr_reader :name

          def initialize(name)
            @name = name
            @required = false
          end

          def on_model_initialize(instance); end

          def instance_value(instance)
            instance.send(name)
          end

          def assign_attribute(instance, attr_value)
            instance.send("#{name}=", attr_value)
          end

          def update_from_redis_data(instance, data, **)
            return unless data.key?(redis_field)

            assign_attribute(instance, from_redis(data[redis_field]))
          end

          def update_from_api_response(instance, value)
            assign_attribute(instance, from_api_response(value))
          end

          def custom?
            false
          end

          def validate(instance)
            value = instance_value(instance)
            if value.nil?
              if required
                instance.errors.add(name, 'value for required attr field is nil')
              end
              return
            end

            types = valid_types.is_a?(Array) ? valid_types : [valid_types]

            return unless types.all? { |type| !value.is_a?(type) }

            instance.errors.add(
              name,
              "value for field is #{value.class} instead of #{valid_types}",
            )
          end
        end

        class PrimitiveImpl < BaseImpl
          def indexable?
            true
          end

          def redis_field
            @name.to_s
          end
        end

        class SerializedImpl < BaseImpl
          def indexable?
            false
          end

          def redis_field
            "#{@name}_json_str"
          end
        end
      end
    end
  end
end
