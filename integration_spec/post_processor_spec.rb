FAST_MODE_REASON = '  -- SKIPPED IN FAST MODE'.freeze
SKIPPED_TESTS_REASON = '  -- SKIPPED SINCE SOME SPECS WERE SKIPPED'.freeze
MANUALLY_SKIPPED_REASON = '  -- MANUALLY SKIPPED'.freeze

# Integration test for the entire post processing function
def make_specs_for(test_groups = {})
  test_count = 0
  test_group_data = test_groups.transform_values do |test_names|
    skip_next = false
    {}.tap do |tests|
      test_names.each do |test_name|
        if test_name == :'#'
          skip_next = true
          next
        end
        if skip_next
          tests[test_name] = :skipped
          skip_next = false
        else
          test_count += 1
          tests[test_name] = Cisqua::TestDataProvider.instance.test_data[test_name.to_s]
        end
      end
    end
  end

  groups_list = make_test_groups_by_iteration(test_group_data)

  groups_list.each_with_index do |groups, i|
    prep_only_iteration = false
    if test_config[:mode] == :prep
      break if test_config[:value] != :all && i + 1 > test_config[:value]

      # We just want to get everything ready, but not run the test at this iteration
      prep_only_iteration = true if i + 1 == test_config[:value] || test_config[:value] == :all
    end

    context "when processor is run for the #{(i + 1).ordinalize} time" do
      if prep_only_iteration
        make_before_all_section_for_groups(groups, false)
        it 'needs a dummy test'
      else
        make_before_all_section_for_groups(groups, true)
        make_specs_for_groups(groups)
      end
    end
  end
  [test_count, Cisqua::TestDataProvider.instance.test_data.count]
end

def make_before_all_section_for_groups(groups, run_process)
  before(:all) do
    groups.each_value do |tests|
      tests.each do |name, test_data|
        next if test_data.nil? || test_data == :skipped

        should_prep_data = test_config[:mode] != :fast || !test_data_has_been_processed?(name, test_data)
        prepare_data(test_data) if should_prep_data
        if test_data.hack_udp_cache
          test_interface.hack_udp_cache_for_test(test_data.hack_udp_cache)
        end
      end
    end
    test_interface.run if run_process
  end
end

def make_specs_for_groups(groups)
  groups.each do |group_name, tests|
    group_name_str = group_name.to_s.gsub('_', ' ')
    context "when the file(s) is/are a #{group_name_str}" do
      tests.each do |test_name, test_data|
        make_specs_for_test(test_name, test_data)
      end
    end
  end
end

def make_test_groups_by_iteration(test_group_data)
  iterations = []
  max_test_array_length = test_group_data.values.map do |tests_data|
    tests_data.values.map { |v| v.is_a?(Array) ? v.size : 0 }
  end.flatten.max || 0
  max_test_array_length.times do |i|
    new_group_data = {}
    test_group_data.each do |group_name, tests_data|
      new_tests_data = {}

      tests_data.each do |test_name, test_data|
        if test_data.nil? || test_data == :skipped
          new_tests_data[test_name] = test_data if i.zero?
          next
        end
        new_tests_data[test_name] = test_data[i] unless test_data[i].nil?
      end
      new_group_data[group_name] = new_tests_data unless new_tests_data.empty?
    end
    iterations << new_group_data unless new_group_data.empty?
  end
  iterations
end

def test_data_has_been_processed?(_name, test_data)
  test_data.files.all? do |f|
    File.symlink?(f.src.path)
  end
end

def make_specs_for_test(name, test_data)
  name_str = name.to_s.gsub('_', ' ')
  if test_data.nil?
    it "must be implemented for #{name_str}" do
      expect(test_data).not_to be_nil
    end

    return
  end
  if test_data == :skipped
    it "should provide implementations for #{name_str}#{MANUALLY_SKIPPED_REASON}"
    return
  end

  context "when the file is #{name_str}" do
    make_specs_for_dst_dir(name, test_data) if test_data.dst_dir

    test_data.files.each do |f|
      if test_config[:mode] == :fast && test_data.skip_checks_in_fast_mode.include?('moves (and symlink back)')
        # rubocop:disable Layout/LineLength
        it "moves (and symlink back) #{f.src.segment} to #{test_data.dst.segment} with name #{f.dst.segment}#{FAST_MODE_REASON}"
        # rubocop:enable Layout/LineLength
      else
        it "moves (and symlink back) #{f.src.segment} to #{test_data.dst.segment} with name #{f.dst.segment}" do
          expect(f.src.path).to be_moved_to_with_source_symlink(f.dst.path)
        end
      end
    end

    test_data.recheck.each do |rt|
      if rt.not_exist_dir
        it "does not have the folder #{rt.not_exist_dir.segment} inside #{rt.dst.segment}" do
          expect(File).not_to(
            exist(rt.not_exist_dir.path),
            "Expect #{rt.not_exist_dir.segment} to not be contained at #{rt.dst.path}",
          )
        end
      end

      rt.files.each do |rt_f|
        if test_config[:mode] == :fast && test_data.skip_checks_in_fast_mode.include?('recheck')
          it "moves processed file #{rt_f.src.segment} to #{rt.dst.segment} and update symlinks#{FAST_MODE_REASON}"
        else
          it "moves processed file #{rt_f.src.segment} to #{rt.dst.segment} and update symlinks" do
            expect(rt_f.src.path).to be_moved_to_with_source_symlink(rt_f.dst.path)
          end
        end
      end
    end
  end
end

def prepare_data(t)
  t.files.each do |f|
    FileUtils.rm_f(f.src.path)
    FileUtils.mkdir_p(File.dirname(f.src.path))
    FileUtils.cp(
      f.pristine.path,
      f.src.path,
    )
  end
end

def make_specs_for_dst_dir(_name, t)
  it "creates the folder #{t.dst_dir.segment} inside #{t.dst.segment}" do
    expect(File).to(
      exist(t.dst_dir.path),
      "Expect #{t.dst_dir.segment} to be contained at #{t.dst.path}",
    )
  end

  it "Creates the anidb.id with value #{t.anidb_id} inside #{t.dst_dir.segment}" do
    content = File.read(File.join(t.dst_dir.path, 'anidb.id'))
    expect(content).to eq("#{t.anidb_id}\n")
  end

  Cisqua::TestDataProvider.instance.dst_dir_symlink_locations.each do |sym|
    if t.dst_dir_symlink_locs.include?(sym.segment)
      if test_config[:mode] == :fast && t.skip_checks_in_fast_mode.include?('has a symlink to')
        it "has a symlink to #{t.dst_dir.segment} from #{sym.segment}#{FAST_MODE_REASON}"
      else
        it "has a symlink to #{t.dst_dir.segment} from #{sym.segment}" do
          expect(
            File.join(sym.path, t.dst_dir.segment),
          ).to be_symlink_to(t.dst_dir.path)
        end
      end
    elsif test_config[:mode] == :fast && t.skip_checks_in_fast_mode.include?('has a symlink to')
      it "does not have a symlink to #{t.dst_dir.segment} from #{sym.segment}#{FAST_MODE_REASON}"
    else
      it "does not have a symlink to #{t.dst_dir.segment} from #{sym.segment}" do
        expect(
          File.join(sym.path, t.dst_dir.segment),
        ).not_to be_symlink_to(t.dst_dir.path)
      end
    end
  end
end

describe Cisqua::PostProcessor do
  before(:all) do
    test_interface.start
    unless test_config[:mode] == :fast
      data_provider = Cisqua::TestDataProvider.instance
      all_locations =
        [
          data_provider.src_location,
        ] + data_provider.dst_locations + data_provider.dst_dir_symlink_locations
      all_locations.each do |loc|
        FileUtils.rm_r(Dir["#{loc.path}/*"])
      end
    end
  end

  after(:all) do
    test_interface.stop
  end

  if test_config[:mode] == :fast
    it "can retrieve details about a show#{FAST_MODE_REASON}"
  else
    it 'can retrieve details about a show' do
      test_data_provider = Cisqua::TestDataProvider.instance
      anime_data = test_interface.anime_data(test_data_provider.test_aid)
      expect(anime_data).to be_equivalent_json_to(test_data_provider.test_pre_scan_library_data)
    end
  end

  test_count, total_test_count = make_specs_for(
    movie: %i[
      movie
      movie_with_subs
      movie_in_parts
      movie_special
      movie_op_or_ed
      movie_with_all_episodes
      episode_of_movie
    ],
    tv_series: %i[
      episode_from_complete_series
      special_episode_from_complete_series
      episode_from_incomplete_series
      episode_from_series_that_becomes_complete
      multi_file_episode
      episode_that_changes_name
    ],
    something_else: %i[
      not_recognized
      episode_of_other
      episode_of_hidden_series
    ],
    duplicate: %i[
      not_recognized_duplicate
      identical_duplicate
      duplicate_that_is_improved
      duplicate_that_is_worse
      non_identical_duplicate_that_is_not_better_or_worse
    ],
  )

  context 'when scans have been completed' do
    let(:test_data_provider) { Cisqua::TestDataProvider.instance }

    should_skip_post_scan_tests = test_count < total_test_count || test_config[:mode] == :prep
    puts "test mode skip is #{should_skip_post_scan_tests ? 'true' : 'false'} because #{test_count}"

    if should_skip_post_scan_tests
      it "has updated details about a show #{SKIPPED_TESTS_REASON}"
      it "has 3 Batches#{SKIPPED_TESTS_REASON}"
    else
      it 'has updated details about a show' do
        anime_data = test_interface.anime_data(test_data_provider.test_aid)
        expect(anime_data).to be_equivalent_json_to(test_data_provider.test_post_scan_library_data)
      end

      it 'has 3 Batches' do
        expect(test_interface.scan_count).to be_equal(3)
      end
    end

    3.times do |index|
      batch_id = index + 1
      keys_to_remove = [
        :started_at,
        :start_date,
        :start_time,
        :duration,
        :source,
      ]

      if should_skip_post_scan_tests
        it "has updated details about batch #{batch_id}#{SKIPPED_TESTS_REASON}"
      else
        it "has updated details about batch #{batch_id}" do
          scans = test_interface.scan_data(batch_id).except(*keys_to_remove.map(&:to_s))
          expect(scans).to be_equivalent_json_to(test_data_provider.test_post_scan_batch_data(batch_id))
        end
      end
    end
  end
end
