require_relative 'attributes/attribute_collection'
require_relative 'attributes/base_attribute'
require_relative 'attributes/bool_attribute'
require_relative 'attributes/float_attribute'
require_relative 'attributes/hash_attribute'
require_relative 'attributes/int_attribute'
require_relative 'attributes/incr_attribute'
require_relative 'attributes/list_attribute'
require_relative 'attributes/string_attribute'
require_relative 'attributes/symbol_attribute'
require_relative 'attributes/time_attribute'

module Cisqua
  module Model
    module Saveable
      module Attributes
        extend ActiveSupport::Concern
        include Redisable
        include ActiveModel::Model

        include BaseAttribute
        include BoolAttribute
        include FloatAttribute
        include HashAttribute
        include IntAttribute
        include IncrAttribute
        include ListAttribute
        include StringAttribute
        include SymbolAttribute
        include TimeAttribute

        class_methods do
          def required_attrs(*attrs)
            model_attrs.mark_as_required(attrs)
          end

          # These attributes combined make up the index and are now required.
          # Allows multiple ways of fetching the item by index
          def index_attrs(*attrs)
            bad_attrs = model_attrs.get_non_indexable_attrs(attrs)
            assert(
              bad_attrs.empty?,
              "attrs #{bad_attrs} in #{name} are used in the index but are not indexable",
            )
            self.index_attr_names = attrs
            model_attrs.mark_as_required(attrs)
            find_method_name = "find_by_#{attrs.join('_and_')}"
            __def_method_with_index_attrs(find_method_name, attrs) do |*args|
              key = make_key(*args)
              find_by_key(key)
            end

            __def_method_with_index_attrs(:find, attrs) do |*args|
              key = make_key(*args)
              instance = find_by_key(key)
              attrs_strings = attrs.zip(args).map { |k, v| "#{k}: #{v}" }
              assert(
                !instance.nil?,
                "Expected to find a #{name} with #{attrs_strings.join(', ')}",
              )
              instance
            end

            define_singleton_method(:find_by) do |**attrs_by_key|
              key_attrs = attrs.map { |attr| attrs_by_key[attr] }
              assert(!key_attrs.any?(&:nil?), 'all key attrs should exist')
              key = make_key(*key_attrs)
              find_by_key(key)
            end

            define_method(:redis_key) do
              values = attrs.map { |field| instance_values[field.to_s] }
              self.class.make_key(*values)
            end
          end

          # This object only has a single instance. So there is no index required
          def single_instance(key)
            @index_attrs = nil
            self.cardinality = :single

            __def_method_with_index_attrs(:find_if_exists, []) do
              find_by_key(key)
            end

            __def_method_with_index_attrs(:find, []) do
              instance = find_by_key(key)
              assert(
                !instance.nil?,
                "Expected to find the single instance of #{name} with #{key}",
              )
              instance
            end

            define_method(:redis_key) do
              key
            end

            define_singleton_method(:make_key) do
              key
            end
          end

          def __def_method_with_index_attrs(method_name, attrs)
            define_singleton_method(method_name) do |*args|
              assert(
                args.length == attrs.length,
                "#{method_name} recieved #{args.count} arguments which does not match the index_attrs #{attrs}",
              )
              yield(*args)
            end
          end
        end

        def initialize(*, **)
          self.class.model_attrs.on_model_initialize(self)
          super
        end

        def has_expected_attrs
          self.class.model_attrs.validate(self)
        end

        def attributes
          self.class.model_attrs.attribute_hash(self)
        end

        def assign_attributes(attributes)
          self.class.model_attrs.assign_attributes(self, attributes)
        end

        included do
          validate :has_expected_attrs
          class_attribute :cardinality
          self.cardinality = :multiple
          class_attribute :index_attr_names
        end
      end
    end
  end
end
