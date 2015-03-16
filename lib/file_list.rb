def file_list(options)
  basedir = options[:basedir]
  extensions = options[:extensions] == :all ? '*' : "{#{extension_glob options[:extensions]}}"
  Dir.glob(File.join("#{basedir}","#{'**/' if options[:recursive]}*.#{extensions}"),File::FNM_CASEFOLD).
    reject {|n| File.symlink? n }
end

def extension_glob(extensions)
  extensions.gsub(/(\w*)\s+(\w*)/, '\1,\2')
end  
