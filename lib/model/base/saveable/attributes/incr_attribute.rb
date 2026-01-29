require_relative 'base_attribute'
require 'forwardable'

module Cisqua
  module Model
    module Saveable
      module Attributes
        module IncrAttribute
          extend ActiveSupport::Concern

          class_methods do
            def incr_attrs(*attrs)
              __add_attrs_to_list(
                attrs,
                Impl,
                read_only: true,
              )
              define_method(:incr) do |name|
                _to_increment[name] = true
                send("#{name}_will_change!")
              end
            end
          end

          def initialize(*, **)
            self._to_increment = {}
            super
          end

          included do
            attr_accessor :_to_increment
          end

          class Impl < PrimitiveImpl
            def validate(value)
              return if value.is_a? Integer

              ["value for field should be of type Integer but is #{value.class.name}"]
            end

            def incr(instance)
              instance.incr(@name)
            end

            def set_int(instance, value)
              instance.instance_variable_set("@#{@name}", value)
            end

            def on_model_initialize(instance)
              set_int(instance, 0)
            end

            def update_from_redis_data(instance, data, **)
              instance.instance_variable_set("@#{@name}", data[redis_field])
            end

            def to_redis(value)
              value.to_s
            end

            def write_to_redis(transaction, instance)
              if instance._status == :new
                transaction.add_operation do |pipeline|
                  value = instance._to_increment[@name] ? 1 : 0
                  pipeline.hsetnx(instance.redis_key, @name, value)
                end
                if instance._to_increment[@name]
                  transaction.on_complete do
                    instance._to_increment.delete(@name)
                    set_int(instance, 1)
                  end
                end
                return
              end

              return unless instance._to_increment[@name]

              future = nil
              transaction.add_operation do |pipeline|
                future = pipeline.hincrby(instance.redis_key, @name, 1)
              end
              transaction.on_complete do
                set_int(instance, future.value)
                instance._to_increment.delete(@name)
              end
            end

            def from_api_response(_value)
              raise "incr attribute #{@name} should not be set from api_response"
            end

            def assign_attribute(instance, attr_value)
              assert(
                attr_value == :incr,
                "cannot set #{attr_value} on an incr attribute",
              )
              incr(instance)
            end

            def custom?
              true
            end
          end
        end
      end
    end
  end
end
