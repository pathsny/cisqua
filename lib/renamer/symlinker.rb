module Renamer
  class Symlinker
    class << self
      def relative(target, source)
        File.symlink(find_relative(target, File.dirname(source)), source)
      end

      def relative_with_name(target, source_dir, name)
        File.symlink(find_relative(target, source_dir), File.join(source_dir, name))
      end

      private
      def find_relative(target, source_dir)
        FileUtils.mkdir_p source_dir
        (Pathname.new target).relative_path_from (Pathname.new source_dir)
      end  
    end
  end
end
