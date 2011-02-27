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
  
  let (:video_file) {File.expand_path('../scan_folder/test_anime.avi', __FILE__)}    

  it 'does not touch files which are not identified' do
    renamer.process(video_file, nil)
    Dir[File.expand_path('../scan_folder/*.*', __FILE__)].count.should == 2
  end

  it 'moves and renames files using the rename_rules'

  it 'escapes special characters'

  it 'moves and renames subtitle files using the same rules'

  it 'does not overwrite existing files'

  it 'moves duplicate files to a duplicate directory'

  it 'preserves multiple duplicates'


  def clean_folders
    FileUtils.rm_r(File.expand_path('../scan_folder/', __FILE__)) rescue
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