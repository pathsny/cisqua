module Cisqua
  module Model
    module Saveable
      class ModelRegistry
        include Singleton

        def initialize
          clear
        end

        def clear
          @models = {}
        end

        def register(klass)
          @models[name(klass)] = klass
        end

        def name(klass)
          klass.name.demodulize.underscore.to_sym
        end

        def get(name)
          @models[name]
        end

        def each_model(&)
          @models.each(&)
        end
      end
    end
  end
end
