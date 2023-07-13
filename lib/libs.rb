ENV['OPENSSL_CONF'] = File.expand_path('.add_provider_conf', __dir__)

require 'amazing_print'
require 'yaml'

ROOT_FOLDER = File.expand_path('..', __dir__)
DATA_FOLDER = File.join(ROOT_FOLDER, 'data')

Dir[File.join(__dir__, '**/*.rb')].each do |f|
  require f unless f == __FILE__
end
