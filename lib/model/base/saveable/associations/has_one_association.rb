require_relative 'base_association'

module Cisqua
  module Model
    module Saveable
      module Associations
        class HasOneAssociation < BaseAssociation
          def additional_validate!
            return if options[:one_way]

            assert(
              inverse_to_owner.type == :immutably_belongs_to,
              error_msg('invalid inverse_to_owner type. Should be immutably_belongs_to'),
            )
          end

          def type
            :has_one
          end

          def define_accessors
            define_single_foreign_key_accessor
          end

          def can_be_nil?
            options[:can_be_nil]
          end

          def requires_inverse_to_function?
            false
          end
        end
      end
    end
  end
end
