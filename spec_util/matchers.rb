module RSpecMatcherUtils
  def self.read_file(name)
    File.open(name) { |f| return f.read }
  end

  def self.resolve_symlink(path)
    File.expand_path(File.readlink(path), File.dirname(path))
  end

  def self.is_symlink_to(src_path, dest_path)
    File.symlink?(src_path) &&
      RSpecMatcherUtils.resolve_symlink(src_path) == dest_path
  end

  def self.is_not_raw_file(path)
    !is_raw_file(path)
  end

  def self.is_raw_file(path)
    File.exist?(path) && !File.symlink?(path)
  end

  def self.content_matches_path(path, content)
    RSpecMatcherUtils.read_file(path) == content
  end

  def self.be_symlink_to_error_message(actual, expected)
    actual_loc = File.basename(actual)
    unless File.exist?(actual) && File.symlink?(actual)
      return "expected #{actual_loc} to be symlink in #{File.dirname(actual)}"
    end

    symlink_target = RSpecMatcherUtils.resolve_symlink(actual)
    unless File.exist?(actual) && symlink_target == expected
      return "expected #{actual_loc} to point to \n" \
             "#{expected} but was \n" \
             "#{symlink_target}"
    end
    return "#{expected} should exist" unless File.exist?(expected)
  end
end

RSpec::Matchers.define :be_symlink_to do |expected|
  match do |actual|
    RSpecMatcherUtils.is_symlink_to(actual, expected)
  end

  failure_message do |actual|
    RSpecMatcherUtils.be_symlink_to_error_message(actual, expected)
  end
end

RSpec::Matchers.define :be_moved do
  match do |actual|
    if actual.is_a?(String)
      RSpecMatcherUtils.is_not_raw_file(actual)
    else
      RSpecMatcherUtils.is_not_raw_file(actual[:path]) ||
        !RSpecMatcherUtils.content_matches_path(actual[:path], actual[:content])
    end
  end

  match_when_negated do |actual|
    if actual.is_a?(String)
      RSpecMatcherUtils.is_raw_file(actual)
    else
      RSpecMatcherUtils.is_raw_file(actual[:path]) &&
        RSpecMatcherUtils.content_matches_path(actual[:path], actual[:content])
    end
  end
end

RSpec::Matchers.define :be_moved_to_without_source_symlink do |expected|
  match do |actual|
    assert(!actual.is_a?(String), 'not yet implemented for strings')
    File.exist?(expected) &&
      actual[:content] == RSpecMatcherUtils.read_file(expected) &&
      (!File.symlink?(actual[:path]) || RSpecMatcherUtils.resolve_symlink(actual[:path]) != expected)
  end

  match_when_negated do |_actual|
    raise 'use .to_not be_moved instead'
  end

  failure_message do |actual|
    break "#{expected} should exist" unless File.exist?(expected)
    break "#{actual[:path]} is a symlink to #{expected} which was not expected" \
      unless !File.symlink?(actual[:path]) || RSpecMatcherUtils.resolve_symlink(actual[:path]) != expected

    actual_content = RSpecMatcherUtils.read_file(expected)
    err_msg = "#{expected} was not moved correctly. " \
              "expected content #{actual[:content]} but was #{actual_content}"
    break err_msg unless actual[:content] == actual_content
  end
end

RSpec::Matchers.define :be_moved_to_with_source_symlink do |expected|
  match do |actual|
    if actual.is_a?(String)
      RSpecMatcherUtils.is_symlink_to(actual, expected)
    else
      RSpecMatcherUtils.is_symlink_to(actual[:path], expected) &&
        RSpecMatcherUtils.content_matches_path(expected, actual[:content])
    end
  end

  match_when_negated do |_actual|
    raise 'use .to_not be_moved instead'
  end

  failure_message do |actual|
    if actual.is_a?(String)
      RSpecMatcherUtils.be_symlink_to_error_message(
        actual,
        expected,
      )
    else
      message = RSpecMatcherUtils.be_symlink_to_error_message(
        actual[:path],
        expected,
      )
      break message unless message.nil?

      actual_content = RSpecMatcherUtils.read_file(expected)
      err_msg = "#{expected} was not moved correctly. " \
                "expected content #{actual[:content]} but was #{actual_content}"
      break err_msg unless actual[:content] == actual_content
    end
  end
end

# RSpec::Matchers.define :be_contained_in do |containing_path|
#   match do |location|
#     File.exist?(File.join(containing_path, location))
#   end

#   match_when_negated do |location|
#     !File.exist?(File.join(containing_path, location))
#   end

#   failure_message do |location|
#     "expected #{location} to exist inside #{containing_path}"
#   end
# end
