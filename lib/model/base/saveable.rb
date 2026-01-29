require_relative 'saveable/associations'
require_relative 'saveable/attributes'
module Cisqua
  module Model
    module Saveable
      extend ActiveSupport::Concern
      extend Cisqua::Reloadable
      include Redisable
      include ActiveModel::Model
      include ActiveModel::Dirty
      include Associations
      include Attributes

      class_methods do
        def has_id_field?
          false
        end

        def find_by_key(key)
          db_provider.read(key) do |redis|
            next nil unless redis.exists?(key)

            instance = new
            model_attrs.read_from_redis(redis, instance, key)
            instance.after_load
          end
        end

        def delete_record(key, transaction)
          transaction.add_operation do |pipeline|
            pipeline.del(key)
          end
        end

        def on_save(method = nil, &block)
          assert(block_given? || method, 'requires a callback')
          assert(!block_given? || !method, 'cannot mix block and method')

          save_callbacks << (block || method)
        end

        def after_save(method = nil, &block)
          assert(block_given? || method, 'requires a callback')
          assert(!block_given? || !method, 'cannot mix block and method')

          after_save_callbacks << (block || method)
        end

        def upsert(transaction: nil, **attrs)
          instance = cardinality == :single ? find_if_exists : find_by(**attrs)
          instance ||= new

          instance.assign_attributes(attrs)
          instance.tap do |i|
            if i.changed? || i._status == :new
              i.update(transaction:)
            else
              i.restore_attributes
            end
          end
        end
      end

      ## Instance Methods

      def update(transaction: nil, **attrs)
        attrs = attrs.merge(updated_at: Time.now) unless attrs.key?(:updated_at)
        assign_attributes(attrs)
        save(transaction:)
      end

      def save(transaction: nil)
        db_provider.write(transaction:) do |tr|
          __save_in_transaction(tr)
        end
      end

      def __save_in_transaction(transaction)
        raise "#{self.class.name} validation failed:\n#{errors.full_messages.join("\n")}" unless valid?

        key = redis_key
        token = db_provider.start_update_cache(key, self, new_value: @_status == :new)
        operation = @_status == :new ? :create : :update
        self.class.model_attrs.write_to_redis(transaction, self)
        __on_save_callback(operation, transaction:)

        transaction.on_complete do
          db_provider.end_update_cache(key, token)
          changes_applied
          @_status = :loaded
          self.class.after_save_callbacks.each do |cb|
            if cb.respond_to?(:call)
              cb.call(self, operation)
            else
              send(cb, operation)
            end
          end
        end

        self
      end

      def __on_save_callback(operation, transaction:)
        self.class.save_callbacks.each do |cb|
          if cb.respond_to?(:call)
            cb.call(self, operation, transaction)
          else
            send(cb, operation, transaction)
          end
        end
      end

      def delete!(transaction = nil)
        db_provider.write(transaction:) { |t| __delete_in_transaction(t) }
      end

      def __delete_in_transaction(transaction)
        key = redis_key
        token = db_provider.start_update_cache(key, nil)

        self.class.delete_record(key, transaction)
        __on_save_callback(:delete, transaction:)
        transaction.on_complete do
          @_status = :deleted
          db_provider.end_update_cache(key, token)
        end
        true
      end

      def save_unique
        raise errors.full_messages.join("\n") unless valid?

        key = redis_key

        raise "duplicate #{self.class.name} with key #{key}" unless self.class.find_by_key(key).nil?

        save
      end

      def after_load
        @_status = :loaded
        clear_changes_information
        self
      end

      def has_id_field?
        self.class.has_id_field?
      end

      def initialize(*, **)
        @_status = :new
        super
      end

      included do
        time_attrs :updated_at
        required_attrs :updated_at
        attr_reader :_status

        class_attribute :save_callbacks, instance_writer: false
        class_attribute :after_save_callbacks, instance_writer: false
        self.save_callbacks = []
        self.after_save_callbacks = []
      end
    end
  end
end
