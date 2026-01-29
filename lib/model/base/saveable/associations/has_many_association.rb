require_relative 'base_association'

module Cisqua
  module Model
    module Saveable
      module Associations
        class HasManyAssociation < BaseAssociation
          def initialize(owner_class, model, options)
            super
            @proxies = {}
          end

          def additional_validate!
            assert(
              !(requires_inverse_to_function? && inverse_to_owner&.requires_inverse_to_function?),
              error_msg(
                'this and the inverse_to_owner are has_many, so one must provide custom_id_method',
              ),
            )

            if has_intermediate?
              # Needs a way to get to the through and from the through to the target.
              assert(
                !intermediate_class.nil?,
                error_msg("intermediate class #{options[:intermediate_model]} not found"),
              )
              assert(!owner_to_intermediate.nil?, error_msg('no route from owner to intermediate'))
              assert(!intermediate_to_target.nil?, error_msg('no route from intermediate to target'))
            end

            if options[:id_alias]
              assert(
                !intermediate_to_target.multiple?,
                error_msg('id alias requires only one intermediate to target'),
              )
            end

            if requires_inverse_to_function?
              assert(
                target_class.cardinality == :single ||
                target_class.has_id_field? ||
                inverse_to_owner.options[:id_attribute],
                error_msg('no mechanism to choose an attribute to represent the target object'),
              )
            end
          end

          def requires_inverse_to_function?
            return false if %i[custom_id_method through one_way id_alias].any? { |option| options[option] }

            true
          end

          def type
            :has_many
          end

          def define_accessors
            define_method_on_owner(plural_id_accessor_name) do |association|
              association.get_proxy(redis_key).ids
            end

            define_method_on_owner(plural_accessor_name) do |association|
              association.get_proxy(redis_key)
            end
          end

          def setup_callbacks
            return unless requires_inverse_to_function?

            assert(
              !inverse_to_owner.nil? && !inverse_to_owner.requires_inverse_to_function?,
              error_msg('requires inverse_to_owner to function, but so does its inverse_to_owner'),
            )

            class_to_track = options[:via] ? intermediate_class : target_class
            class_to_track.on_save do |instance, operation, transaction|
              keys_of_owner_instances(instance).each do |redis_key|
                attributes = target_attributes(instance)
                proxy = get_proxy(redis_key)
                case operation
                when :create, :update
                  proxy.ids.add_many(transaction:, ids: attributes)
                when :delete
                  proxy.ids.remove_many(transaction:, ids: attributes)
                else
                  raise "unsupported operation type #{operation}"
                end
              end
            end
          end

          # The keys of the target_model from this instance of the owner
          def foreign_keys(instance)
            raise error_msg('unsupported method') unless options[:custom_id_method]

            instance.send(options[:custom_id_method])
          end

          # The instance maybe of the target model or the intermediate model
          # if this is a via association.
          def keys_of_owner_instances(instance)
            return [owner_class.make_key] if owner_class.cardinality == :single

            inverse_to_owner.foreign_keys(instance).map { |k| owner_class.make_key(k) }
          end

          # The instance maybe of the target model or the intermediate model
          # if this is a via association.
          def target_attributes(instance)
            if options[:via]
              intermediate_to_target.foreign_keys(instance)
            else
              [inverse_to_owner.instance_attribute(instance)]
            end
          end

          def get_through_proxy(instance)
            instance.send(options[:through])
          end

          def get_proxy(redis_key)
            @proxies[redis_key] ||= make_proxy(redis_key)
          end

          def accessor_name
            super.pluralize
          end

          def multiple?
            true
          end

          private

          def make_proxy(redis_key)
            proxy_key = redis_set_key(redis_key)
            id_proxy = make_id_proxy(redis_key, proxy_key)
            AssociatedObjectsProxy.new(
              id_proxy,
              ->(target_id) { target_instance(redis_key, target_id) },
              ->(target_instance) { target_attribute(target_instance) },
              object_proxy_debug_info,
            )
          end

          def make_id_proxy(redis_key, proxy_key)
            if options[:custom_id_method]
              AssociatedIdsCustomProxy.new(id_proxy_debug_info) do
                instance = owner_instance(redis_key)
                instance.send(options[:custom_id_method])
              end
            elsif options[:through]
              AssociatedIdsThroughProxy.new(
                proxy_key,
                intermediate_to_target,
                -> { owner_to_intermediate.get_proxy(redis_key) },
                id_proxy_debug_info,
              )
            elsif options[:id_alias]
              owner_to_intermediate.get_proxy(redis_key).ids
            else
              AssociatedIdsSetProxy.new(
                owner_class.db_provider,
                proxy_key,
                id_proxy_debug_info,
              )
            end
          end

          def base_proxy_debug_info
            { model: owner_class, instance: target_class }
          end

          def object_proxy_debug_info
            base_proxy_debug_info.merge(contents: plural_accessor_name)
          end

          def id_proxy_debug_info
            base_proxy_debug_info.merge(contents: plural_id_accessor_name)
          end

          def owner_instance(redis_key)
            owner_class.find_by_key(redis_key)
          end

          def target_instance(redis_key, id)
            if target_class.index_attr_names.count == 1
              return target_class.find(id)
            end

            owner = owner_instance(redis_key)
            if owner.has_id_field?
              return target_class.find(owner.id, id)
            end

            assert(options[:id_attribute], 'must have id_attribute')
            target_class.find(owner.send(options[:id_attribute]), id)
          end

          def target_attribute(target_instance)
            if target_instance.has_id_field?
              return target_instance.id
            end

            assert(
              inverse_from_target,
              'Without an ID Field, we need the target_to_owner association to have an id_attribute',
            )
            inverse_from_target.instance_attribute(target_instance)
          end

          def redis_set_key(redis_key)
            "#{redis_key}:#{redis_key_suffix}"
          end

          def redis_key_suffix
            return nil if options[:custom_id_method]
            return options[:redis_key_part].to_s unless options[:redis_key_part].nil?

            plural_accessor_name
          end

          def plural_id_accessor_name
            return options[:short_id_name] if options[:short_id_name]

            if target_class.has_id_field?
              return "#{singular_accessor_name}_ids"
            end

            assert(!inverse_from_target.nil?, 'inverse_from_target must exist')
            assert(inverse_from_target.options.key?(:id_attribute), 'cannot identify id attribute')
            "#{singular_accessor_name}_#{inverse_from_target.options[:id_attribute]}".pluralize
          end
        end
      end
    end
  end
end
