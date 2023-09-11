module Cisqua
  module Model
    module Saveable
      extend ActiveSupport::Concern
      include Redisable
      include ActiveModel::Model

      class_methods do
        def int_attrs(*attrs)
          @int_attrs = (@int_attrs + attrs).uniq.sort
          attr_accessor(*attrs)
        end

        def int_attr_list
          @int_attrs
        end

        def bool_attrs(*attrs)
          @bool_attrs = (@bool_attrs + attrs).uniq.sort
          attr_accessor(*attrs)
        end

        def bool_attr_list
          @bool_attrs
        end

        def time_attrs(*attrs)
          @time_attrs = (@time_attrs + attrs).uniq.sort
          attr_accessor(*attrs)
        end

        def time_attr_list
          @time_attrs
        end

        def symbol_attrs(*attrs)
          @symbol_attrs = (@symbol_attrs + attrs).uniq.sort
          attr_accessor(*attrs)
        end

        def symbol_attr_list
          @symbol_attrs
        end

        def attr_list
          (
            int_attr_list +
            bool_attr_list +
            string_attr_list +
            symbol_attr_list +
            time_attr_list
          ).sort
        end

        def string_attrs(*attrs)
          @string_attrs = (@string_attrs + attrs).uniq
          attr_accessor(*attrs)
        end

        def string_attr_list
          @string_attrs
        end

        def unique_attrs(*attrs)
          @unique_attrs = attrs
          find_method_name = "find_by_#{attrs.join('_and_')}"
          def_method_with_unique_attrs(find_method_name, attrs) do |*args|
            key = make_key(*args)
            find_by_key(key)
          end

          def_method_with_unique_attrs(:find, attrs) do |*args|
            instance = send(find_method_name, *args)
            attrs_strings = attrs.zip(args).map { |k, v| "#{k}: #{v}" }
            assert(
              !instance.nil?,
              "Expected to find a #{name} with #{attrs_strings.join(', ')}",
            )
            instance
          end
        end

        def other_required_attrs(*attrs)
          @other_required_attrs = (@other_required_attrs + attrs).uniq.sort
        end

        def required_attr_list
          @other_required_attrs + unique_attr_list
        end

        def find_by_key(key)
          return nil unless redis.exists?(key)

          data = redis.hgetall(key).symbolize_keys
          from_redis(data)
        end

        def def_method_with_unique_attrs(method_name, attrs)
          define_singleton_method(method_name) do |*args|
            assert(
              args.length == attrs.length,
              "#{method_name} only recieved #{args.count} arguments which does not match the unique_attrs #{attrs}",
            )
            yield(*args)
          end
        end

        def unique_attr_list
          @unique_attrs
        end

        def from_redis(data)
          transformed_data = data.each_with_object({}) do |(k, v), obj|
            obj[k] = if bool_attr_list.include?(k)
              v == 'true'
            elsif int_attr_list.include?(k)
              v.to_i
            elsif time_attr_list.include?(k)
              Time.at(v.to_i)
            elsif symbol_attr_list.include?(k)
              v.to_sym
            else
              assert(string_attr_list.include?(k), "unknown attribute type #{k} for #{name}")
              v
            end
          end
          (attr_list - transformed_data.keys).each do |k|
            transformed_data[k] = nil
          end
          new(transformed_data)
        end

        def to_redis(key, instance_values)
          attributes = attr_list.each_with_object({}) do |k, obj|
            v = instance_values[k.to_s]
            next if v.nil?

            obj[k.to_s] = if time_attr_list.include?(k)
              v.to_i.to_s
            else
              is_known_attr = [
                bool_attr_list,
                symbol_attr_list,
                int_attr_list,
                string_attr_list,
              ].any? { |list| list.include?(k) }
              assert(is_known_attr, "unknown attribute type #{k} for #{name}")
              v.to_s
            end
          end
          redis.hset(key, *attributes.flatten)
        end

        def before_save(*cbs)
          @before_save_cbs += cbs
        end

        def after_save(*cbs)
          @after_save_cbs += cbs
        end

        def after_save_callback(instance)
          @after_save_cbs.map { |m| instance.send(m) }
        end

        def before_save_callback(instance, key)
          return if @before_save_cbs.empty?

          saved_instance = find_by_key(key)
          @before_save_cbs.map { |m| instance.send(m, saved_instance) }
        end
      end

      def has_expected_attrs
        expected_attrs = self.class.required_attr_list

        expected_attrs.each do |field|
          errors.add(field, 'value for required attr field is nil') if instance_values[field.to_s].nil?
        end
      end

      def make_key_for_instance
        values = self.class.unique_attr_list.map do |field|
          instance_values[field.to_s]
        end
        self.class.make_key(*values)
      end

      def update(attrs)
        attrs = attrs.merge(updated_at: Time.now) unless attrs.key?(:updated_at)
        assign_attributes(attrs)
        save
      end

      def save
        raise errors.full_messages.join("\n") unless valid?

        key = make_key_for_instance
        self.class.before_save_callback(self, key)
        self.class.to_redis(make_key_for_instance, instance_values)
        self.class.after_save_callback(self)
        self
      end

      def save_unique
        raise errors.full_messages.join("\n") unless valid?

        key = make_key_for_instance

        raise "duplicate #{self.class.name} with key #{key}" unless self.class.find_by_key(key).nil?

        save
      end

      included do
        validate :has_expected_attrs
        @time_attrs = [:updated_at]
        @string_attrs = []
        @symbol_attrs = []
        @int_attrs = []
        @bool_attrs = []
        @custom_api_transforms = {}

        attr_accessor :updated_at

        @unique_attrs = []
        @other_required_attrs = %i[updated_at]
        @after_save_cbs = []
        @before_save_cbs = []
      end
    end
  end
end
