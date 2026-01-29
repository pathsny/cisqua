module Cisqua
  module Model
    module Saveable
      class AttributeCollection
        include SemanticLogger::Loggable
        attr_accessor :attrs

        def initialize
          @attrs = {}
          @custom = []
          @standard = []
        end

        def add(attr_class, names)
          invalid = names.select do |name|
            @attrs[name] && @attrs[name].class != attr_class
          end

          assert(
            invalid.empty?,
            "attributes #{invalid} added multiple times with different classes",
          )

          names.each do |name|
            attr = attr_class.new(name)
            @attrs[name] = attr
          end
        end

        def get_non_indexable_attrs(names)
          @attrs.values.select do |attr|
            names.include?(attr.name) && !attr.indexable?
          end
        end

        def send_to(name, method, *args)
          attr = @attrs[name]
          assert(
            attr,
            "#{method} called for #{name} which does not exist",
          )
          attr.send(method, *args)
        end

        def mark_as_required(names)
          @attrs.each_value { |attr| attr.required = true if names.include?(attr.name) }
        end

        def on_model_initialize(instance)
          @attrs.each_value { |attr| attr.on_model_initialize(instance) }
        end

        def names
          @attrs.values.map(&:name)
        end

        def redis_fields_to_read
          @attrs.values.map(&:redis_field)
        end

        def attribute_hash(instance)
          @attrs.values.each_with_object({}) do |attr, obj|
            obj[attr.name] = instance.send(attr.name)
          end
        end

        def validate(instance)
          @attrs.each_value do |attr|
            attr.validate(instance)
          end
        end

        def read_from_redis(redis, instance, key)
          data = redis.hgetall(key)
          unknown_keys = data.keys - redis_fields_to_read
          assert(
            unknown_keys.empty?,
            "unknown attributes #{unknown_keys} for #{instance.class.name} removed #{redis_fields_to_read}",
          )
          @attrs.each_value do |attr|
            attr.update_from_redis_data(instance, data, redis:, key:)
          end
        end

        def write_to_redis(transaction, instance)
          data = @attrs.each_value.with_object({ missing: [], to_write: {} }) do |attr, obj|
            if attr.custom?
              attr.write_to_redis(transaction, instance)
              next
            end

            value = instance.send(attr.name)
            if value.nil?
              obj[:missing] << attr.redis_field
              next
            end

            obj[:to_write][attr.redis_field] = attr.to_redis(value)
          end

          transaction.add_operation do |pipeline|
            pipeline.hdel(instance.redis_key, *data[:missing]) unless data[:missing].empty?
            pipeline.hset(instance.redis_key, *data[:to_write].flatten)
          end
          transaction.on_rollback do
            instance.restore_attributes
          end
        end

        def update_from_api_response(instance, attributes)
          attributes.each do |attr, value|
            @attrs[attr].update_from_api_response(instance, value)
          end
        end

        def assign_attributes(instance, attributes)
          attributes.each do |attr, value|
            @attrs[attr].assign_attribute(instance, value)
          end
        end
      end
    end
  end
end
