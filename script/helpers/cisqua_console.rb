# console for debugging
require 'yaml'
require 'optparse'
require 'pry'
require File.expand_path('../../lib/libs', __dir__)

C = Struct.new(:options_file, :test_mode, :registry, :maintenance).new
OptionParser.new do |opts|
  opts.banner = 'Usage: create_symlinks -o <options file> -m <mylist_location>'
  opts.on('-oOPTIONS', '--options=OPTIONS', 'location of options config') do |o|
    C.options_file = o
  end
  opts.on('-t', '--test_mode', 'whether to start in test mode') do
    C.test_mode = true
  end
end.parse!

module Cisqua
  class StandaloneConsole
    include Singleton

    def start
      AppLogger.log_file = File.join(DATA_FOLDER, 'log', 'console.log')

      registry_klass = Cisqua::Registry
      registry_klass.options_file_override = C.options_file
      registry_klass.test_mode_override = C.test_mode

      Pry::Commands.block_command 'r!', 'reload all the code' do |*_args|
        load File.join(Cisqua::ROOT_FOLDER, 'lib', 'util', 'registry.rb')

        registry_klass.reload!
        C.registry = registry_klass.instance
        C.maintenance = Cisqua::Maintenance.new
      end

      Cisqua::EmbeddedConsole.instance.start
    end
  end
end

Cisqua::StandaloneConsole.instance.start
