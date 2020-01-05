require 'yaml'

module ScriptOptions
  def self.load_options(options_file)
    options_file = File.expand_path('../../data/options.yml', __dir__) unless options_file
    YAML.load_file(options_file)
  end
end
