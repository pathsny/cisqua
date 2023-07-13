require 'yaml'

module ScriptOptions
  def self.load_options(options_file)
    options_file ||= File.join(DATA_FOLDER, 'options.yml')
    YAML.load_file(options_file)
  end
end
