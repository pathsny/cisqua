require_relative('test_data_provider')
require_relative('test_util')

# Integration test for the entire post processing function
RSpec.configure do |_config|
  Cisqua::AppLogger.disable_stdout_logging
  Cisqua::TestUtil.prep(log_level: :debug)
  # Runs faster, but maybe inaccurate. Useful for development
  # We dont clear the file data between runs, so only the final
  # result can be asserted.
  def should_run_fast_mode
    @should_run_fast_mode ||= (ENV['FAST_MODE'] || false)
  end

  def make_specs_for(test_groups)
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
            tests[test_name] = Cisqua::TestDataProvider.instance.test_data[test_name.to_s]
          end
        end
      end
    end

    groups_list = make_test_groups_by_iteration(test_group_data)

    before(:all) do
      @processor = Cisqua::PostProcessor.new(
        Cisqua::Registry.instance.options,
        Cisqua::Registry.instance.scanner,
        Cisqua::FileProcessor.instance,
      )
      @processor.start
    end

    after(:all) do
      @processor.stop
    end

    groups_list.each_with_index do |groups, i|
      break if i > 1
      context "when processor is run for the #{(i + 1).ordinalize} time" do
        make_before_all_section_for_groups(groups)
        make_specs_for_groups(groups)
      end
    end
  end

  def make_before_all_section_for_groups(groups)
    before(:all) do
      groups.each do |_group_name, tests|
        tests.each do |name, test_data|
          next if test_data.nil? || test_data == :skipped

          fast_mode = should_run_fast_mode && ready_for_fast_mode(name, test_data)
          prepare_data(test_data) unless fast_mode
        end
      end
      @processor.run
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
    end.flatten.max
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

  def make_specs_for_test(name, test_data)
    name_str = name.to_s.gsub('_', ' ')
    if test_data.nil?
      it "must be implemented for #{name_str}" do
        expect(test_data).not_to be_nil
      end

      return
    end
    if test_data == :skipped
      it "should provide an implementation for #{name_str}"
      return
    end

    if should_run_fast_mode && !can_support_fast_mode(name, test_data)
      it "is skipped for #{name} in fast_mode"
      return
    end

    context "when the file is #{name_str}" do
      make_specs_for_dst_dir(name, test_data) if test_data.dst_dir

      test_data.files.each do |f|
        it "moves (and symlink back) #{f.src.segment} to #{test_data.dst.segment} with name #{f.dst.segment}" do
          expect(f.src.path).to be_moved_to_with_source_symlink(f.dst.path)
        end
      end

      test_data.recheck.each do |rt|
        rt.files.each do |rt_f|
          it "moves processed file #{rt_f.src.segment} to #{rt.dst.segment} and update symlinks" do
            expect(rt_f.src.path).to be_moved_to_with_source_symlink(rt_f.dst.path)
          end
        end
      end
    end
  end

  def ready_for_fast_mode(_name, test_data)
    test_data.all? do |t|
      t.files.all? do |f|
        File.symlink?(f.src.path) &&
          RSpecMatcherUtils.resolve_symlink(f.src.path) == f.dst.path
      end
    end
  end

  # In fast mode, we dont clean up properly. So lets check that all the
  # data is already as if the test ran.
  def can_support_fast_mode(name, test_data)
    # Any test that involves re-checking after some operations cannot
    # work in fast mode

    return false unless test_data.map(&:recheck).map(&:empty?).all?
    return false if name == :not_recognized_duplicate

    true
  end
end

def prepare_data(t)
  t.files.each do |f|
    FileUtils.rm_f(f.src.path)
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
      it "has a symlink to #{t.dst_dir.segment} from #{sym.segment}" do
        expect(
          File.join(sym.path, t.dst_dir.segment),
        ).to be_symlink_to(t.dst_dir.path)
      end
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
  unless should_run_fast_mode
    before(:all) do
      Cisqua::RedisScripts.instance.start_redis(
        Cisqua::Registry.options_override.redis.conf_path,
      )
      redis = Cisqua::Registry.instance.redis
      data_provider = Cisqua::TestDataProvider.instance
      all_locations =
        [
          data_provider.src_location,
        ] + data_provider.dst_locations +
        data_provider.dst_dir_symlink_locations
      all_locations.each do |loc|
        FileUtils.rm_r(Dir["#{loc.path}/*"])
      end
    end

    after(:all) do
      Cisqua::RedisScripts.instance.stop_redis
    end
  end

  make_specs_for(
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
end
