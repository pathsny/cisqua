# Expected symlinks to the directory for a test file after processing.
require_relative 'test_data_provider'

TestDataLocation = Struct.new(
  'TestDataLocation',
  :segment,
  :absolute_path,
  :containing_location,
  keyword_init: true,
) do
  # full pathname for location
  def path
    absolute_path || File.join(containing_location.path, segment)
  end
end

TestDataFileMovement = Struct.new(
  :pristine,
  :src,
  :dst,
  keyword_init: true,
)

TestDataType = Struct.new(
  'TestDataType',
  :src,
  :dst,
  :pristine,
  # directory if one is created
  :dst_dir,
  # locations that symlink to dst_dir. String or Array
  :dst_dir_symlink_locs,
  # info about each file and how it is processed Array[TestDataTypeFileInfo]
  :files,
  # Array of test_info to recheck
  :recheck,
  :anidb_id,
) do
  def initialize(name, test_data, base_locations)
    self.src = base_locations[:src_loc]
    self.pristine = base_locations[:pristine_loc]

    if test_data['dst_loc']
      self.dst = base_locations[:dst_locs].find do |loc|
        loc.segment == test_data['dst_loc']
      end
      assert(
        dst,
        "unknown dst #{test_data['dst_loc']} for #{name}",
      )
    else
      self.dst = base_locations[:default_dst]
    end

    if test_data.key?('dst_dir')
      self.dst_dir = TestDataLocation.new(
        segment: test_data['dst_dir'],
        containing_location: dst,
      )
      self.dst_dir_symlink_locs = case test_data['dst_dir_symlink_from']
      when nil
        []
      when String
        [test_data['dst_dir_symlink_from']]
      when Array
        test_data['dst_dir_symlink_from']
      else
        assert(false, "unsupported value for dst_dir_symlink_from in #{name}")
      end
    else
      assert(
        !test_data.key?('dst_dir_symlink_from'),
        "error with test #{name}. dst_dir_symlink_from without dst_dir",
      )
      self.dst_dir = nil
      self.dst_dir_symlink_locs = nil
    end
    initialize_file_info(
      name,
      test_data['src_name'],
      test_data['dst_name'],
      test_data['pristine_src_name'],
    )
    self.recheck = (test_data['recheck'] || []).map do |info|
      TestDataType.new(
        name,
        info,
        base_locations,
      )
    end
    self.anidb_id = test_data['anidb_id']
  end

  def initialize_file_info(name, src_names, dst_names, pristine_src_names)
    dst_names = src_names if dst_names.nil?
    pristine_src_names = src_names if pristine_src_names.nil?

    if src_names.is_a?(String)
      assert(
        dst_names.is_a?(String),
        "Error in test test_data for #{name}. A single src can only have a single dst",
      )
      assert(
        pristine_src_names.is_a?(String),
        "Error in test test_data for #{name}. A single src can only have a single pristine src",
      )
      src_names, dst_names, pristine_src_names = [src_names], [dst_names], [pristine_src_names]
    end
    assert(
      src_names.count == dst_names.count,
      "Error in test test_data for #{name}. src_name and dst_name must have same count",
    )
    assert(
      src_names.count == pristine_src_names.count,
      "Error in test test_data for #{name}. src_name and pristine_src_name must have same count",
    )
    self.files = src_names.zip(
      dst_names,
      pristine_src_names,
    ).map do |src_name, dst_name, pristine_src_name|
      TestDataFileMovement.new(
        src: TestDataLocation.new(
          segment: src_name,
          containing_location: src,
        ),
        dst: TestDataLocation.new(
          segment: dst_name,
          containing_location: dst_dir || dst,
        ),
        pristine: TestDataLocation.new(
          segment: pristine_src_name,
          containing_location: pristine,
        ),
      )
    end
  end
end
