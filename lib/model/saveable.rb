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

        def string_attrs(*attrs)
          @string_attrs = (@string_attrs + attrs).uniq
          attr_accessor(*attrs)
        end

        def string_attr_list
          @string_attrs
        end

        def hash_attrs(*attrs)
          @hash_attrs = (@hash_attrs + attrs).uniq
          add_serialized_attrs(attrs) do |value|
            value.nil? || value.is_a?(Hash) ? [true, nil] : [false, 'it is not a hash']
          end
        end

        def list_attrs(*attrs)
          @list_attrs = (@list_attrs + attrs).uniq
          add_serialized_attrs(attrs) do |value|
            value.nil? || value.is_a?(Array) ? [true, nil] : [false, 'it is not an array']
          end
        end

        def add_serialized_attrs(attrs)
          attrs.each do |attr|
            var_name = "@#{serialized_attr_var_name(attr)}"
            define_method(attr) do
              str_val = instance_variable_get(var_name)
              str_val && JSON.parse(str_val)
            end

            define_method("#{attr}=") do |value|
              is_valid, error_reason = yield(value)
              assert(
                is_valid,
                "Invalid value #{value} for attr #{attr} because #{error_reason}",
              )
              instance_variable_set(var_name, value&.to_json)
            end
          end
        end

        def serialized_attr_var_name(attr)
          "#{attr}_json_str"
        end

        def serialized_attr_var_names
          serialized_attr_list.map do |attr|
            serialized_attr_var_name(attr)
          end
        end

        def serialized_attr_list
          @hash_attrs + @list_attrs
        end

        def hash_attr_list
          @hash_attrs
        end

        def list_attr_list
          @list_attrs
        end

        def attr_list
          (
            int_attr_list +
            bool_attr_list +
            string_attr_list +
            symbol_attr_list +
            time_attr_list +
            serialized_attr_list
          ).sort
        end

        def redis_key_list
          simple_attrs = (
            int_attr_list +
            bool_attr_list +
            string_attr_list +
            symbol_attr_list +
            time_attr_list
          ).map(&:to_s)
          (simple_attrs + serialized_attr_var_names).sort
        end

        def unique_attrs(*attrs)
          @unique_attrs = attrs
          assert(
            !serialized_attr_list.intersect?(attrs),
            'serialized attrs not supported as unique attrs',
          )
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

          data = redis.hgetall(key)
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
          unknown_keys = data.keys - redis_key_list
          assert(unknown_keys.empty?, "unknown attributes #{unknown_keys} for #{name}")
          transformed_data = attr_list.each_with_object({}) do |k, obj|
            rkey = case k
            when *serialized_attr_list
              serialized_attr_var_name(k)
            else
              k.to_s
            end
            obj[k] = if data.key?(rkey)
              v = data[rkey]
              case k
              when *bool_attr_list
                v == 'true'
              when *int_attr_list
                v.to_i
              when *time_attr_list
                Time.at(v.to_i)
              when *symbol_attr_list
                v.to_sym
              when *serialized_attr_list
                JSON.parse(v)
              else
                v
              end
            end
          end
          new(transformed_data)
        end

        def to_redis(key, instance_values)
          attributes = redis_key_list.each_with_object({ missing: [], data: {} }) do |k, obj|
            value = instance_values[k]
            if value.nil?
              obj[:missing] << k
              next
            end

            obj[:data][k] = case k
            when *time_attr_list.map(&:to_s)
              value.to_i.to_s
            else
              value.to_s
            end
          end
          redis.hdel(key, *attributes[:missing]) unless attributes[:missing].empty?
          redis.hset(key, *attributes[:data].flatten)
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

        def clear_record(*values)
          key = make_key(*values)
          redis.del(key)
        end
      end

      ## Instance Methods

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

      def attributes
        self.class.attr_list.each_with_object({}) do |attr, hash|
          hash[attr] = send(attr)
        end
      end

      included do
        validate :has_expected_attrs
        @time_attrs = [:updated_at]
        @string_attrs = []
        @symbol_attrs = []
        @int_attrs = []
        @bool_attrs = []
        @hash_attrs = []
        @list_attrs = []
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
