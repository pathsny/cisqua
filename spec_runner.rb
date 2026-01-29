#!/usr/bin/env ruby

require 'open3'
require 'solid_assert'

SolidAssert.enable_assertions

# Function to run the command and print output
def run_command(command, env = {})
  puts "Running: #{command}"
  Open3.popen3(env, command) do |_stdin, stdout, stderr, wait_thr|
    while (line = stdout.gets)
      puts line
    end
    while (line = stderr.gets)
      puts line
    end
    exit_status = wait_thr.value
    unless exit_status.success?
      abort "Command failed with exit status #{exit_status.exitstatus}"
    end
  end
end

def build_command(base_command, type, inputs)
  case type
  when :unit
    helper = File.expand_path('spec/spec_helper', __dir__)
    "#{base_command} --require #{helper} #{inputs}"
  when :integration
    helper = File.expand_path('integration_spec/spec_helper', __dir__)
    "#{base_command} --require #{helper} --format documentation #{inputs}"
  else
    abort "Unknown command type: #{type}"
  end
end

def do_command(command, type)
  case type
  when :unit
    run_command(command)
  when :integration
    run_command(command, 'TEST_INTERFACE' => 'cli')
  else
    abort "Unknown command type: #{type}"
  end
end

def pattern_command(type, pre_inputs, patterns, post_inputs)
  return if patterns.empty?

  command = build_command(
    'bundle exec rspec',
    type,
    pre_inputs +
    "--pattern '#{patterns.join(',')}' " +
    post_inputs,
  )
  do_command(command, type)
end

if ARGV.empty?
  abort "Usage: #{$PROGRAM_NAME} '<input_string>'"
end
pattern_index = ARGV.index('--pattern')
path_input = ARGV.find { |arg| arg =~ /_spec.rb(?::\d+)?$/ }

if pattern_index
  pattern_input = ARGV[pattern_index + 1]
  pre_inputs = ARGV[0...pattern_index].join(' ')
  post_inputs = ARGV[(pattern_index + 2)..].join(' ')

  # Extract the pattern and the remaining options
  patterns = pattern_input.split(',')
  unit_patterns = []
  integration_patterns = []

  patterns.each do |pattern|
    match_data = %r{.*/(integration_?)(spec/)(\*\*)/.*}.match(pattern)
    assert(match_data, "Pattern #{pattern} does not match expected format")
    suffix = match_data[1]

    case suffix
    when 'integration_'
      integration_patterns << pattern
    else
      unit_patterns << pattern
    end
  end
  puts "I see #{integration_patterns} integration"
  puts "I see #{unit_patterns} unit"

  pattern_command(:unit, pre_inputs, unit_patterns, post_inputs)
  pattern_command(:integration, pre_inputs, integration_patterns, post_inputs)
elsif path_input
  # Handle case where a specific spec file path is provided
  path_index = ARGV.index(path_input)
  before_path_input = ARGV[0...path_index].join(' ')
  after_path_input = ARGV[(path_index + 1)..].join(' ')

  if path_input.include?('/integration_spec/')
    command = build_command('bundle exec rspec', :integration, "#{before_path_input} #{path_input} #{after_path_input}")
    run_command(command, 'TEST_INTERFACE' => 'cli')
  else
    command = build_command('bundle exec rspec', :unit, "#{before_path_input} #{path_input} #{after_path_input}")
    run_command(command)
  end
else
  abort 'Missing --pattern or path in input arguments'
end
