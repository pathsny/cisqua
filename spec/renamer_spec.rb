require File.expand_path('../spec_helper', __FILE__)

describe 'renamer' do
  let (:info) { 1 }

  before :each do
    clean_folders
    create_test_files
    stub_rename_rules_to_return('foo - bar')
  end

  after :each do
    clean_folders
  end

  let (:renamer) { Renamer.new(nil) }
  subject {renamer}

  let (:video_file) {File.expand_path('../scan_folder/test_anime.avi', __FILE__)}    

  it 'does not touch files which are not identified' do
    renamer.process(video_file, nil)
    Dir[File.expand_path('../scan_folder/*.*', __FILE__)].count.should == 2
  end

  describe '#escape' do
    RSpec::Matchers.define :escape_to do |expected|
      match do |actual|
        subject.escape(actual) == expected 
      end
    end

    it { 'fate/stay'.should escape_to 'fate stay' }
    it { 'macross: the movie'.should escape_to 'macross the movie' }
    it { 'space :movie'.should escape_to 'space movie' }
    it { '//hack root'.should escape_to 'hack root'}
    it { 'hi there $$ man'.should escape_to 'hi there man' }
    it { 'hello%%%romeo'.should escape_to "hello romeo" }
    it { 'blaaah   blueeee    bleeeeeeh'.should escape_to 'blaaah blueeee bleeeeeeh'}
  end  

  it 'moves and renames files using the rename_rules'

  it 'escapes special characters'

  it 'moves and renames subtitle files using the same rules'

  it 'does not overwrite existing files'

  it 'moves duplicate files to a duplicate directory'

  it 'preserves multiple duplicates'


  def clean_folders
    FileUtils.rm_r(File.expand_path('../scan_folder/', __FILE__)) 
  rescue
  end

  def create_test_files
    FileUtils.mkdir(File.expand_path('../scan_folder/', __FILE__))
    File.open(File.expand_path('../scan_folder/test_anime.avi', __FILE__), 'w') {|f| f.write('gibberish')}
    File.open(File.expand_path('../scan_folder/test_anime.sub', __FILE__), 'w') {|f| f.write('subs')}
  end

  def stub_rename_rules_to_return(retval)
    Object.stubs(:generate_name).with(1).returns(retval)
  end


end