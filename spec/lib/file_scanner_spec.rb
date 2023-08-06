describe Cisqua::FileScanner do
  it 'lists non recursive files' do
    scanner = described_class.new(basedir: '/Movies', extensions: :all, recursive: false)
    Dir.expects(:glob).with('/Movies/*.*', File::FNM_CASEFOLD).returns([])
    scanner.file_list
  end

  it 'lists recursive files' do
    scanner = described_class.new(basedir: '/Movies', extensions: :all, recursive: true)
    Dir.expects(:glob).with('/Movies/**/*.*', File::FNM_CASEFOLD).returns([])
    scanner.file_list
  end

  it 'lists only files with the requested extensions' do
    scanner = described_class.new(basedir: '/Movies', extensions: 'avi mkv srt', recursive: true)
    Dir.expects(:glob).with('/Movies/**/*.{avi,mkv,srt}', File::FNM_CASEFOLD).returns([])
    scanner.file_list
  end
end
