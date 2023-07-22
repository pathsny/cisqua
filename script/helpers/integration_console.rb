# console for debugging
require_relative('../../integration_spec/spec_helper')

def logger
  return @logger if @logger

  AppLogger.log_file = File.join(DATA_FOLDER, 'log', 'console.log')
  @logger = SemanticLogger['IntegrationConsole']
end

def r
  Dir[File.expand_path('../../integration_spec/*', __dir__)].each do |f|
    load f unless f.match(/.*_spec\.rb/)
  end
end

r
