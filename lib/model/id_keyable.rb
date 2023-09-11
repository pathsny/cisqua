module Cisqua
  module Model
    module IDKeyable
      extend ActiveSupport::Concern
      include Model::Saveable

      included do
        string_attrs :id
        unique_attrs :id
      end

      class_methods do
        def key_prefix(prefix)
          @key_prefix = prefix
        end

        def make_key(id)
          "#{@key_prefix}:#{id}"
        end
      end
    end
  end
end
