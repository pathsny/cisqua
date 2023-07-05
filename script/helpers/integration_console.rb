# console for debugging
require_relative('../../integration_spec/spec_helper')

def r
  Dir[File.expand_path('../../integration_spec/*', __dir__)].each do |f|
    load f unless f.match(/.*_spec\.rb/)
  end
end

r
