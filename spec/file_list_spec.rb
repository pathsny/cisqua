describe 'filelist' do
  it 'lists non recursive files' do
    Dir.expects(:glob).with('/Movies/*.*', File::FNM_CASEFOLD).returns([])
    file_list(basedir: '/Movies', extensions: :all, recursive: false)
  end

  it 'lists recursive files' do
    Dir.expects(:glob).with('/Movies/**/*.*', File::FNM_CASEFOLD).returns([])
    file_list(basedir: '/Movies', extensions: :all, recursive: true)
  end

  it 'lists only files with the requested extensions' do
    Dir.expects(:glob).with('/Movies/**/*.{avi,mkv,srt}', File::FNM_CASEFOLD).returns([])
    file_list(basedir: '/Movies', extensions: 'avi mkv srt', recursive: true)
  end
end
