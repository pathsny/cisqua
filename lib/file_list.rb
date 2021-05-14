def file_list(options)
  basedir = options[:basedir]
  extensions = options[:extensions] == :all ? '*' : "{#{extension_glob options[:extensions]}}"
  Dir.glob(File.join("#{basedir}","#{'**/' if options[:recursive]}*.#{extensions}"),File::FNM_CASEFOLD).
    reject {|n| File.symlink? n }
end

def symlink_for(target, basedir)
  Dir.glob(File.join("#{basedir}","**/*.*"), File::FNM_CASEFOLD).select do |n|
    File.symlink?(n) &&
    File.expand_path(File.readlink(n), File.dirname(n)) == target
  end
end

def extension_glob(extensions)
  extensions.gsub(/(\w*)\s+(\w*)/, '\1,\2')
end
