require 'openssl'

module Cisqua
  class FileScanner
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def file_list
      basedir = File.absolute_path(options[:basedir], ROOT_FOLDER)
      extensions = options[:extensions] == :all ? '*' : "{#{extension_glob options[:extensions]}}"
      Dir.glob(File.join(basedir.to_s, "#{'**/' if options[:recursive]}*.#{extensions}"), File::FNM_CASEFOLD)
        .reject { |n| File.symlink? n }
    end

    def extension_glob(extensions)
      extensions.gsub(/(\w*)\s+(\w*)/, '\1,\2')
    end

    def ed2k_file_hash(file_name)
      # ed2k block size is 9500 KiB
      ed2k_block = 9500 * 1024
      ed2k_hash = ''
      file_size = nil
      File.open(file_name, 'rb') do |f|
        file_size = f.stat.size # while at it, fetch the size of the file
        while (block = f.read(ed2k_block))
          # hashes are concatenated md4 per block size for ed2k hash
          ed2k_hash << OpenSSL::Digest::MD4.digest(block)
        end
        # on size of modulo block size, append another md4 hash of a blank string
        ed2k_hash << OpenSSL::Digest.digest('MD4', '') if (file_size % ed2k_block).zero?
      end
      # finally
      ed2k_hash = file_size >= ed2k_block ? OpenSSL::Digest::MD4.hexdigest(ed2k_hash) : ed2k_hash.unpack1('H*')
      [file_size, ed2k_hash]
    end
  end
end
