require_relative('test_data_provider')

# Integration test for the entire post processing function
RSpec.configure do |_config|
  def options
    @options ||= Options.load_options(nil).tap do |options|
      options[:log_level] = :debug
      options[:renamer][:plex_scan_library_files] = nil
    end
  end

  # Runs faster, but maybe inaccurate. Useful for development
  # We dont clear the file data between runs, so only the final
  # result can be asserted.
  def should_run_fast_mode
    @should_run_fast_mode ||= (ENV['FAST_MODE'] || false)
  end

  def make_specs_for(test_groups)
    test_groups.each do |group_name, test_names|
      group_name_str = group_name.to_s.gsub('_', ' ')
      context "when the file(s) is/are a #{group_name_str}" do
        skip_next = false
        test_names.each do |test_name|
          if skip_next
            it "should provide an implementation for #{test_name}"
            skip_next = false
            next
          end
          if test_name == :'#'
            # Indicates the next test is commented
            skip_next = true
            next
          end
          make_specs_for_test(
            test_name,
            TestDataProvider.instance.test_data[test_name.to_s],
          )
        end
      end
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
    if should_run_fast_mode && !can_support_fast_mode(name, test_data)
      it "is skipped for #{name} in fast_mode"
      return
    end

    context_str_segment = test_data.count == 1 ? 'file is' : 'files are'

    context "when the #{context_str_segment} #{name_str}" do
      fast_mode = should_run_fast_mode && ready_for_fast_mode(name, test_data)
      make_specs_for_helper(name, test_data, fast_mode, 1)
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

  def make_specs_for_helper(name, test_data, fast_mode, loop_count)
    t = test_data.first

    unless fast_mode
      before(:all) do
        prepare_data(t)
      end
    end

    make_specs_for_dst_dir(name, t) if t.dst_dir

    t.files.each do |f|
      it "moves (and symlink back) #{f.src.segment} to #{t.dst.segment} with name #{f.dst.segment}" do
        expect(f.src.path).to be_moved_to_with_source_symlink(f.dst.path)
      end
    end

    t.recheck.each do |rt|
      rt.files.each do |rt_f|
        it "moves processed file #{rt_f.src.segment} to #{rt.dst.segment} and update symlinks" do
          expect(rt_f.src.path).to be_moved_to_with_source_symlink(rt_f.dst.path)
        end
      end
    end

    remaining = test_data.drop(1)
    return if remaining.empty?

    context "when #{loop_count} #{loop_count > 1 ? 'files have' : 'file has'} been processed" do
      make_specs_for_helper(name, remaining, fast_mode, loop_count + 1)
    end
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
  PostProcessor.run(options, true)
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

  TestDataProvider.instance.dst_dir_symlink_locations.each do |sym|
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

describe PostProcessor do
  unless should_run_fast_mode
    before(:all) do
      all_locations =
        [
          TestDataProvider.instance.src_location,
        ] + TestDataProvider.instance.dst_locations +
        TestDataProvider.instance.dst_dir_symlink_locations
      all_locations.each do |loc|
        FileUtils.rm_r(Dir["#{loc.path}/*"])
      end
    end
  end

  context 'when processor is run' do
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
end
