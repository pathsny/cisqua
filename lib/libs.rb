ENV['OPENSSL_CONF'] = File.expand_path('.add_provider_conf', __dir__)

require 'active_model'
require 'active_support'
require 'active_support/all'
require 'amazing_print'
require 'redis'
require 'semantic_logger'
require 'yaml'
require 'solid_assert'

SolidAssert.enable_assertions

module Cisqua
  module Reloadable
    def reloadable_const_define(name, value = nil)
      value = yield if value.nil? && block_given?

      remove_const(name) if const_defined?(name)
      const_set(name, value)
    end
  end
end

module Cisqua
  extend Cisqua::Reloadable

  reloadable_const_define :ROOT_FOLDER, File.expand_path('..', __dir__)
  reloadable_const_define :DATA_FOLDER, File.join(ROOT_FOLDER, 'data')

  Dir[File.join(__dir__, '**/*.rb')].each do |f|
    require f unless f == __FILE__
  end
end
