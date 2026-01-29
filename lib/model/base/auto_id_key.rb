require_relative 'id_keyable_base'

module Cisqua
  module Model
    module AutoIdKey
      extend ActiveSupport::Concern
      include Model::IDKeyableBase

      included do
        string_attrs :id, read_only: true
        index_attrs :id
      end

      class_methods do
        def create(transaction: nil, **attrs)
          assert(!attrs.key?(:id), 'id is auto-generated, do not provide it')
          instance = new(**attrs)
          id = make_id
          instance.instance_variable_set(:@id, id)
          db_provider.write(transaction:) do |t|
            instance.update(transaction: t)
          end
        end

        def make_id
          assert(!@key_prefix.nil?, "class #{name} does not define a key prefix")
          id_key = "#{@key_prefix}_count"
          db_provider.bypass_cache do |redis|
            redis.incr(id_key).to_s
          end
        end

        def last_id
          db_provider.bypass_cache do |redis|
            redis.get("#{@key_prefix}_count").to_i
          end
        end
      end

      def id=(value)
        # Allow setting the ID during loading from Redis
        if @_status == :new
          instance_variable_set(:@id, value)
        else
          raise ArgumentError,
            "Cannot set ID on #{self.class} - IDs are auto-generated and read-only after initialization"
        end
      end
    end
  end
end
