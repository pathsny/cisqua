require_relative 'associations/belongs_to_association'
require_relative 'associations/has_many_association'
require_relative 'associations/associated_objects_proxy'
require_relative 'associations/has_one_association'

module Cisqua
  module Model
    module Saveable
      module Associations
        extend ActiveSupport::Concern
        include Redisable
        include ActiveModel::Model

        class_methods do
          def has_one(model, foreign_key:, **kwargs)
            association_definitions <<
              HasOneAssociation.new(self, model, kwargs.merge(foreign_key:))
          end

          def immutably_belongs_to(model, **kwargs)
            association_definitions <<
              BelongsToAssociation.new(self, model, kwargs)
          end

          def has_many(model, **)
            association_definitions << HasManyAssociation.new(self, model, **)
          end

          def build_associations!
            association_definitions.each do |assoc|
              assoc.validate!
              assoc.define_accessors
              assoc.setup_callbacks
            end
          end

          def clear_associations
            self.association_definitions = []
          end

          def find_associations_to(model)
            association_definitions.select { |assoc| assoc.model == model }
          end

          def find_association_to(model, scope: nil)
            associations = find_associations_to(model)
            return nil if associations.empty?

            assert(
              associations.count == 1 || !scope.nil?,
              "ambiguous association to #{model} from #{self} found, please specify scope",
            )
            associations.find do |assoc|
              assoc.options[:scope] == scope
            end
          end
        end

        included do
          class_attribute :association_definitions
          self.association_definitions = []
        end
      end
    end
  end
end
