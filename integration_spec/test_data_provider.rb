require_relative('../lib/libs')
require_relative('test_data_type')
require 'singleton'
require 'json'
require 'pathname'

class TestDataProvider
  TEST_DATA_ROOT = File.expand_path('../data/test_data', __dir__)
  include Singleton

  attr_reader :test_data, :options

  def initialize
    @options = Options.load_options(nil)
    test_info = JSON.load_file!(File.join(
      TEST_DATA_ROOT, 'test_data.json'
    ))
    @pristine_loc = TestDataLocation.new(
      segment: test_info['pristine_sources'],
      containing_location: root_location,
    )
    @test_data = {}
    test_info['scenarios'].each do |name, test_data|
      test_data = [test_data] unless test_data.is_a?(Array)
      @test_data[name] = test_data.map do |test_data_part|
        TestDataType.new(
          name,
          test_data_part,
          default_dst: default_dst_location,
          src_loc: src_location,
          dst_locs: dst_locations,
          pristine_loc: @pristine_loc,
          dst_dir_symlink_locs: dst_dir_symlink_locations,
        )
      end
    end
  end

  def root_location
    TestDataLocation.new(segment: 'root', absolute_path: TEST_DATA_ROOT)
  end

  def src_location
    make_location_from_option_key(:scanner, :basedir)
  end

  def default_dst_location
    make_location_from_option_key(:renamer, :output_location)
  end

  def pristine_location
    @pristine_loc
  end

  def dst_locations
    %i[
      output_location
      duplicate_location
      junk_duplicate_location
      unknown_location
    ].map { |type| make_location_from_option_key(:renamer, type) }
  end

  def dst_dir_symlink_locations
    @options.dig(:renamer, :create_symlinks).values.map do |v|
      make_location_from_option_path(v)
    end
  end

  def make_location_from_option_key(*args)
    option_value = @options.dig(*args)
    make_location_from_option_path(option_value)
  end

  def make_location_from_option_path(option_path)
    full_path = File.expand_path(option_path, ROOT_FOLDER)
    location_name = Pathname.new(full_path).relative_path_from(
      Pathname.new(TEST_DATA_ROOT),
    ).to_s
    TestDataLocation.new(
      segment: location_name,
      containing_location: root_location,
    )
  end
end
