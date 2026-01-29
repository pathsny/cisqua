require_relative 'id_keyable_base'

module Cisqua
  module Model
    module IDKeyable
      extend ActiveSupport::Concern
      include Model::IDKeyableBase

      included do
        string_attrs :id
        index_attrs :id
      end
    end
  end
end
