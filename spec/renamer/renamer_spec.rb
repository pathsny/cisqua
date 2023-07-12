describe Renamer::Renamer do
  include FakeFS::SpecHelpers

  subject { Renamer::Renamer.new(options[:renamer]) }

  before do
    Renamer::NameGenerator.any_instance
      .stubs(:generate_name_and_path)
      .returns(['Anime Name', 'Anime Name - episode number'])
    FileUtils.mkdir_p('/path/to/src_dir')
  end

  let(:source_video) { create_source_file('/path/to/src_dir/file_1.mkv') }
  let(:options) { OPTIONS_BAK }
  let(:dest_dir) { '/path/to/files/Anime Name' }
  let(:dest_file_name) { 'Anime Name - episode number.mkv' }
  let(:dest_file_name_suff_1) { 'Anime Name - episode number.1.mkv' }
  let(:dest) { File.join(dest_dir, dest_file_name) }
  let(:symlink_loc) { '/path/to/incomplete tv series, oav and web' }
  let(:incorrect_symlink_loc) { '/path/to/complete tv series, oav and web' }

  describe :try_process do
    context 'when the file is unknown' do
      before do
        @response = subject.try_process(WorkItem.new(source_video[:path], nil))
      end

      it { expect(@response.type).to eq(:unknown) }
      it { expect(@response.destination).to eq('/path/to/Unknown/file_1.mkv') }
      it { expect(source_video).to be_moved_to_with_source_symlink('/path/to/Unknown/file_1.mkv') }
    end

    context 'when the file is identified' do
      before do
        FileUtils.mkdir_p(incorrect_symlink_loc)
        File.symlink('../files/Anime Name', File.join(incorrect_symlink_loc, 'Anime Name'))
        @response = subject.try_process(WorkItem.new(source_video[:path], DUMMY_INFO))
      end

      it { expect(@response.type).to eq(:success) }
      it { expect(@response.destination).to eq(dest) }
      it { expect(source_video).to be_moved_to_with_source_symlink(dest) }
      it { expect(File.join(symlink_loc, 'Anime Name')).to be_symlink_to(dest_dir) }
      it { expect(File.join(incorrect_symlink_loc, 'Anime Name')).not_to be_symlink_to(dest_dir) }
    end

    context 'when the file is a duplicate' do
      before do
        FileUtils.mkdir_p(dest_dir)
        FileUtils.touch(dest)
        @response = subject.try_process(WorkItem.new(source_video[:path], DUMMY_INFO))
      end

      it { expect(@response.type).to eq(:duplicate) }
      it { expect(@response.destination).to eq(dest) }
      it { expect(source_video).not_to be_moved }
    end
  end

  describe :process_duplicate_set do
    let(:dest_video) { create_source_file(dest) }
    let(:junk_video) { create_source_file('/path/to/src_dir/junk_file.mkv') }
    let(:dup_video) { create_source_file('/path/to/src_dir/dup_file.mkv') }
    let(:source_item) { WorkItem.new(source_video[:path], DUMMY_INFO) }
    let(:dest_item) { WorkItem.new(dest_video[:path], DUMMY_INFO) }
    let(:junk_item) { WorkItem.new(junk_video[:path], DUMMY_INFO) }
    let(:dup_item) { WorkItem.new(dup_video[:path], DUMMY_INFO) }
    let(:junk_loc) { '/path/to/duplicate_junk' }
    let(:dup_loc) { '/path/to/duplicate' }
    let(:old_symlink_dir) { '/path/to/anime/somewhere/deep' }
    let(:old_symlink_loc) { File.join(old_symlink_dir, 'crazy_name.mkv') }
    let(:additional_source_symlink) { '/path/to/anime/foo.mkv' }

    before do
      FileUtils.mkdir_p(dest_dir)
      dest_video
      FileUtils.mkdir_p('/path/to/anime/somewhere/deep')
      File.symlink("../../../files/Anime Name/#{dest_file_name}", old_symlink_loc)
      File.symlink("../files/Anime Name/#{dest_file_name}", additional_source_symlink)
    end

    shared_examples 'handles junk and duplicates' do
      it { expect(junk_video).to be_moved_to_with_source_symlink(File.join(junk_loc, dest_file_name)) }
      it { expect(dup_video).to be_moved_to_with_source_symlink(File.join(dup_loc, dest_file_name)) }
    end

    context 'when keep_current is true' do
      before do
        Renamer::DuplicateResolver
          .stubs(:resolve)
          .returns({
                     keep_current: true,
                     selected: dest_item,
                     junk: [junk_item, source_item],
                     dups: [dup_item],
                   })
        subject.process_duplicate_set(dest_item, [source_item, junk_item, dup_item])
      end

      it_behaves_like 'handles junk and duplicates'
      it { expect(dest_video).not_to be_moved }
      it { expect(source_video).to be_moved_to_with_source_symlink(File.join(junk_loc, dest_file_name_suff_1)) }
    end

    context 'when keep_current is false' do
      before do
        Renamer::DuplicateResolver
          .stubs(:resolve)
          .returns({
                     keep_current: false,
                     selected: source_item,
                     junk: [junk_item],
                     dups: [dup_item],
                   })
        subject.process_duplicate_set(dest_item, [source_item, junk_item, dup_item])
      end

      it_behaves_like 'handles junk and duplicates'
      it { expect(source_video).to be_moved_to_with_source_symlink(dest) }
      it { expect(dest_video).to be_moved_to_without_source_symlink(File.join(junk_loc, dest_file_name_suff_1)) }
      it { expect(old_symlink_loc).to be_symlink_to(File.join(junk_loc, dest_file_name_suff_1)) }
    end
  end
end
