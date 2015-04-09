describe Renamer::VideoFileMover do
  include FakeFS::SpecHelpers

  let(:source_dir) { "/deep/source".tap { |d| FileUtils.mkdir_p(d) } }
  let(:dest_dir) {"/deep/dest"}
  let (:source_video) { create_source_file("#{source_dir}/file_1.mkv") }

  shared_examples "file mover" do |matcher_name|

    alias_method :be_moved_to, matcher_name

    it "moves the file to the given location" do
      subject.process(source_video[:path], dest_dir)
      expect(source_video).to be_moved_to("#{dest_dir}/file_1.mkv")
    end

    it "renames the file to the new name" do
      subject.process(source_video[:path], dest_dir, :new_name => "myfile")
      expect(source_video).to be_moved_to("#{dest_dir}/myfile.mkv")
    end

    it "also moves sub files if they exist" do
      sub_file_1 = create_source_file("#{source_dir}/file_1.sub")
      sub_file_2 = create_source_file("#{source_dir}/file_1.srt")
      subject.process(source_video[:path], dest_dir, :new_name => "myfile")
      expect(sub_file_1).to be_moved_to("#{dest_dir}/myfile.sub")
      expect(sub_file_2).to be_moved_to("#{dest_dir}/myfile.srt")
    end

    it "returns a successful response when it moves files, with the destination" do
      res = subject.process(source_video[:path], dest_dir, :new_name => "myfile")
      expect(res.type).to be :success
      expect(res.destination).to eq "#{dest_dir}/myfile.mkv"
    end

    it "returns a duplicate response if there is already a file at the destination" do
      FileUtils.mkdir_p dest_dir
      FileUtils.touch("#{dest_dir}/myfile.mkv")
      res = subject.process(source_video[:path], dest_dir, :new_name => "myfile")
      expect(res.type).to be :duplicate
      expect(res.destination).to eq "#{dest_dir}/myfile.mkv"
    end

    it "should not move the files if there is already a file at the destination" do
      sub_file_1 = create_source_file("#{source_dir}/file_1.sub")
      sub_file_2 = create_source_file("#{source_dir}/file_1.srt")
      FileUtils.mkdir_p dest_dir
      FileUtils.touch("#{dest_dir}/myfile.mkv")
      subject.process(source_video[:path], dest_dir, :new_name => "myfile")
      expect(source_video).to_not be_moved
      expect(sub_file_1).to_not be_moved
      expect(sub_file_1).to_not be_moved
    end

    it "should move files with a distinct suffix if moved unambiguously" do
      sub_file = create_source_file("#{source_dir}/file_1.sub")
      FileUtils.mkdir_p dest_dir
      FileUtils.touch("#{dest_dir}/myfile.mkv")
      FileUtils.touch("#{dest_dir}/myfile.1.mkv")         
      subject.process(source_video[:path], dest_dir, :new_name => "myfile", :unambiguous => true)
      expect(source_video).to be_moved_to("#{dest_dir}/myfile.2.mkv")
    end

    it "can update existing symlinks if required" do
      sub_file = create_source_file("#{source_dir}/file_1.sub")
      symlink_dir = "/deep/inner/symlinks"
      FileUtils.mkdir_p symlink_dir
      Renamer::Symlinker.relative_with_name(source_video[:path], symlink_dir, "file_1.mkv")
      Renamer::Symlinker.relative_with_name(sub_file[:path], symlink_dir, "file_1.sub")
      subject.process(source_video[:path], dest_dir, :new_name => "myfile", :update_links_from => "/deep/inner")
      expect(source_video).to be_moved_to("#{dest_dir}/myfile.mkv")
      expect(File.join(symlink_dir, "file_1.mkv")).to be_symlink_to("#{dest_dir}/myfile.mkv")
      expect(File.join(symlink_dir, "file_1.sub")).to be_symlink_to("#{dest_dir}/myfile.sub")
    end  
  end  

  context "without source symlinks" do
    subject { Renamer::VideoFileMover.new(:subtitle_extensions => "srt sub") }
    it_behaves_like "file mover", :be_moved_to_without_source_symlink

    it "can create symlinks if overriden" do
      subject.process(source_video[:path], dest_dir, :symlink_source => true)
      expect(source_video).to be_moved_to_with_source_symlink("#{dest_dir}/file_1.mkv")
    end  
  end   

  context "with source symlinks" do
    subject { Renamer::VideoFileMover.new(
      :subtitle_extensions => "srt sub", 
      :symlink_source => true
    ) }
    it_behaves_like "file mover", :be_moved_to_with_source_symlink

    it "can avoid symlinks if overriden" do
      subject.process(source_video[:path], dest_dir, :symlink_source => false)
      expect(source_video).to be_moved_to_without_source_symlink("#{dest_dir}/file_1.mkv")
    end  
  end
end