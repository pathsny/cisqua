describe Cisqua::Renamer::VideoFileMover do
  include FakeFS::SpecHelpers

  subject { described_class.new(subtitle_extensions: 'srt sub') }

  let(:source_dir) { '/deep/source'.tap { |d| FileUtils.mkdir_p(d) } }
  let(:dst_dir) { '/deep/dest' }
  let(:source_video) { create_source_file("#{source_dir}/file_1.mkv") }
  let(:symlinker) { Cisqua::Renamer::Symlinker.new(dry_run_mode: false) }

  shared_examples 'file mover' do |matcher_name|
    alias_method :be_moved_to, matcher_name

    it 'moves the file to the given location' do
      subject.process(src_file: source_video[:path], dst_dir:, **move_options)
      expect(source_video).to be_moved_to("#{dst_dir}/file_1.mkv")
    end

    it 'renames the file to the new name' do
      subject.process(src_file: source_video[:path], dst_dir:, new_name: 'myfile', **move_options)
      expect(source_video).to be_moved_to("#{dst_dir}/myfile.mkv")
    end

    it 'also moves sub files if they exist' do
      sub_file_1 = create_source_file("#{source_dir}/file_1.sub")
      sub_file_2 = create_source_file("#{source_dir}/file_1.srt")
      subject.process(src_file: source_video[:path], dst_dir:, new_name: 'myfile', **move_options)
      expect(sub_file_1).to be_moved_to("#{dst_dir}/myfile.sub")
      expect(sub_file_2).to be_moved_to("#{dst_dir}/myfile.srt")
    end

    it 'returns a successful response when it moves files, with the destination' do
      res = subject.process(src_file: source_video[:path], dst_dir:, new_name: 'myfile', **move_options)
      expect(res.type).to be :success
      expect(res.destination).to eq "#{dst_dir}/myfile.mkv"
    end

    it 'returns a duplicate response if there is already a file at the destination' do
      FileUtils.mkdir_p dst_dir
      FileUtils.touch("#{dst_dir}/myfile.mkv")
      res = subject.process(src_file: source_video[:path], dst_dir:, new_name: 'myfile', **move_options)
      expect(res.type).to be :duplicate
      expect(res.destination).to eq "#{dst_dir}/myfile.mkv"
    end

    it 'does not move the files if there is already a file at the destination' do
      sub_file_1 = create_source_file("#{source_dir}/file_1.sub")
      sub_file_2 = create_source_file("#{source_dir}/file_1.srt")
      FileUtils.mkdir_p dst_dir
      FileUtils.touch("#{dst_dir}/myfile.mkv")
      subject.process(src_file: source_video[:path], dst_dir:, new_name: 'myfile', **move_options)
      expect(source_video).not_to be_moved
      expect(sub_file_1).not_to be_moved
      expect(sub_file_2).not_to be_moved
    end

    it 'moves files with a distinct suffix if moved unambiguously' do
      _sub_file = create_source_file("#{source_dir}/file_1.sub")
      FileUtils.mkdir_p dst_dir
      FileUtils.touch("#{dst_dir}/myfile.mkv")
      FileUtils.touch("#{dst_dir}/myfile.1.mkv")
      subject.process(src_file: source_video[:path], dst_dir:, new_name: 'myfile', unambiguous: true, **move_options)
      expect(source_video).to be_moved_to("#{dst_dir}/myfile.2.mkv")
    end

    # rubocop:disable RSpec/ExampleLength
    it 'can update existing symlinks if required' do
      sub_file = create_source_file("#{source_dir}/file_1.sub")
      symlink_dir = '/deep/inner/symlinks'
      FileUtils.mkdir_p symlink_dir
      symlinker.relative_with_name(source_video[:path], symlink_dir, 'file_1.mkv')
      symlinker.relative_with_name(sub_file[:path], symlink_dir, 'file_1.sub')
      subject.process(
        src_file: source_video[:path],
        dst_dir:,
        new_name: 'myfile',
        update_links_from: '/deep/inner',
        **move_options,
      )
      expect(source_video).to be_moved_to("#{dst_dir}/myfile.mkv")
      expect(File.join(symlink_dir, 'file_1.mkv')).to be_symlink_to("#{dst_dir}/myfile.mkv")
      expect(File.join(symlink_dir, 'file_1.sub')).to be_symlink_to("#{dst_dir}/myfile.sub")
    end
    # rubocop:enable RSpec/ExampleLength
  end

  context 'without source symlinks' do
    let(:move_options) { {} }

    it_behaves_like 'file mover', :be_moved_to_without_source_symlink
  end

  context 'with source symlinks' do
    let(:move_options) { { symlink_source: true } }

    it_behaves_like 'file mover', :be_moved_to_with_source_symlink
  end
end
