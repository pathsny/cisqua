require_relative 'base_association'

module Cisqua
  module Model
    module Saveable
      module Associations
        class BelongsToAssociation < BaseAssociation
          def additional_validate!
            assert(
              !options[:foreign_key].nil? || target_class.cardinality == :single,
              error_msg('target_class instance cannot be identified'),
            )
            return unless inverse_to_owner

            assert(
              %i[has_one has_many].include?(inverse_to_owner.type),
              error_msg('has invalid inverse_to_owner type'),
            )
          end

          def type
            :immutably_belongs_to
          end

          def requires_inverse_to_function?
            false
          end

          # The keys of the target_model from this instance of the owner
          def foreign_keys(instance)
            [instance.send(options[:foreign_key])]
          end

          def define_accessors
            define_single_foreign_key_accessor
          end
        end
      end
    end
  end
end
