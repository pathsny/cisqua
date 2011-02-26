def file_list(options)
  basedir = options[:basedir]
  extensions = options[:extensions] == :all ? '*' : "{#{extension_glob options[:extensions]}}"
  Dir["#{basedir}/#{'**/' if options[:recursive]}*.#{extensions}"]
end

def extension_glob(extensions)
  extensions.gsub(/(\w*)\s+(\w*)/, '\1,\2')
end  
