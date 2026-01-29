module Cisqua
  module Model
    module IDKeyableBase
      extend ActiveSupport::Concern
      include Model::Saveable

      class_methods do
        def key_prefix(prefix)
          @key_prefix = prefix
        end

        def make_key(id)
          assert(!@key_prefix.nil?, "class #{name} does not define a key prefix")
          "#{@key_prefix}:#{id}"
        end

        def has_id_field?
          true
        end
      end
    end
  end
end
