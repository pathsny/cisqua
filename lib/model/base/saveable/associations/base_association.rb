module Cisqua
  module Model
    module Saveable
      module Associations
        class BaseAssociation
          include SemanticLogger::Loggable

          attr_reader :owner_class, :model, :options, :singular_accessor_name, :plural_accessor_name

          def initialize(owner_class, model, options)
            @owner_class = owner_class
            @options = options
            if multiple?
              @plural_accessor_name = options[:short_name] || model
              @singular_accessor_name = @plural_accessor_name.to_s.singularize
              @model = model.to_s.singularize.to_sym
            else
              @singular_accessor_name = options[:short_name] || model
              @plural_accessor_name = @singular_accessor_name.to_s.pluralize
              @model = model
            end

            intermediate = options[:through] || options[:via] || options[:id_alias]
            return unless intermediate

            intermediate_model = intermediate.to_s.singularize.to_sym
            options.merge!(intermediate_model:)
          end

          def validate!
            assert(!target_class.nil?, error_msg("#{model} was not found"))

            associations_to_target = owner_class.find_associations_to(model)
            if associations_to_target.count > 1
              scopes = associations_to_target.map { |assoc| assoc.options[:scope] }
                .compact
                .uniq
              assert(
                scopes.count == associations_to_target.count,
                error_msg("multiple associations to #{model} found, please distinguishe them by adding a scope"),
              )
              assert(
                scopes.all? { |scope| !scope.nil? },
                error_msg("all associations to #{model} must have a scope"),
              )
            end

            if options[:one_way]
              assert(inverse_to_owner.nil?,
                error_msg("one_way association has an inverse_to_owner #{inverse_to_owner}"))
            elsif requires_inverse_to_function?
              assert(!inverse_to_owner.nil?, error_msg('inverse_to_owner was not found and association is not one_way'))
            end

            additional_validate!
          end

          def setup_callbacks
            # No callbacks needed usually
          end

          def error_msg(extra_contents)
            msg_parts = [
              'Association error: ',
              "owner: #{self}",
              "scope: #{options[:scope]}",
            ]
            if inverse_to_owner
              msg_parts << "inverse_to_owner: #{inverse_to_owner}"
            end
            (msg_parts + [extra_contents]).join("\n      ")
          end

          def to_s
            "class: #{owner_class.name}, model: #{model}, type: #{type}"
          end

          def define_method_on_owner(method_name, &block)
            association = self
            owner_class.define_method(method_name) do
              instance_exec(association, &block)
            end
          end

          def define_single_foreign_key_accessor
            find_method = can_be_nil? ? :find_by_id : :find
            define_method_on_owner(singular_accessor_name) do |association|
              key = send(association.options[:foreign_key])
              if find_method == :find
                assert(
                  !key.nil?,
                  "nil foreign key for #{association.singular_accessor_name} on #{association.model}",
                )
              end
              association.target_class.send(find_method, key)
            end
          end

          def can_be_nil?
            false
          end

          def target_class
            ModelRegistry.instance.get(model)
          end

          def owner_model
            ModelRegistry.instance.name(owner_class)
          end

          def intermediate_model
            options[:intermediate_model]
          end

          def has_intermediate?
            !intermediate_model.nil?
          end

          def intermediate_class
            return nil unless has_intermediate?

            ModelRegistry.instance.get(intermediate_model)
          end

          def intermediate_to_target
            return nil unless has_intermediate?

            intermediate_class.find_association_to(
              model,
              scope: options[:through_scope],
            )
          end

          def owner_to_intermediate
            return nil unless has_intermediate?

            owner_class.find_association_to(
              options[:intermediate_model],
              scope: options[:scope],
            )
          end

          def inverse_to_owner
            source_model = has_intermediate? ? options[:intermediate_model] : model
            source_class = ModelRegistry.instance.get(source_model)
            source_class.find_association_to(
              owner_model,
              scope: options[:scope],
            )
          end

          def inverse_from_target
            if has_intermediate?
              model_from_target = intermediate_model
              scope = options[:through_scope]
            else
              model_from_target = owner_model
              scope = options[:scope]
            end
            target_class.find_association_to(
              model_from_target,
              scope:,
            )
          end

          def instance_attribute(instance)
            if options[:id_attribute]

              return instance.send(options[:id_attribute])
            end

            assert(instance.has_id_field?, 'only supported now')
            instance.id
          end

          def target_ids_from_instance(instance)
            if multiple?
              instance.send(plural_accessor_name).ids
            else
              foreign_keys(instance)
            end
          end

          def multiple?
            false
          end
        end
      end
    end
  end
end
