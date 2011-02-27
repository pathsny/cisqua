require File.expand_path('../../lib/file_list', __FILE__)
require 'mocha'

describe 'filelist' do
  it 'lists non recursive files' do
    Dir.expects(:[]).with('/Movies/*.*')
    file_list(:basedir => '/Movies', :extensions => :all, :recursive => false) 
  end
  
  it 'lists recursive files' do
    Dir.expects(:[]).with('/Movies/**/*.*')
    file_list(:basedir => '/Movies', :extensions => :all, :recursive => true) 
  end
  
  it 'lists only files with the requested extensions' do
    Dir.expects(:[]).with('/Movies/**/*.{avi,mkv,srt}')
    file_list(:basedir => '/Movies', :extensions => 'avi mkv srt', :recursive => true)
  end       
end