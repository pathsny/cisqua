require 'amazing_print'
require 'yaml'
require_relative '../external/lru_hash'

ROOT_FOLDER = File.expand_path(File.join(__dir__, '..'))

Dir[File.join(__dir__, '**/*.rb')].each do |f|
  require f unless f == __FILE__
end
