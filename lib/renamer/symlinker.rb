module Cisqua
  module Renamer
    class Symlinker
      include SemanticLogger::Loggable

      def initialize(options)
        @options = options
      end

      def relative(target, source)
        make_symlink(find_relative(target, File.dirname(source)), source)
      end

      def relative_with_name(target, source_dir, name)
        make_symlink(find_relative(target, source_dir), File.join(source_dir, name))
      end

      private

      def find_relative(target, source_dir)
        unless File.directory?(source_dir)
          dry_run = @options[:dry_run_mode] ? ' DRY RUN' : ''
          logger.debug(
            'Creating directory',
            location: source_dir,
            DRY_RUN: dry_run,
          )
          FileUtils.mkdir_p(source_dir) unless @options[:dry_run_mode]
        end
        (Pathname.new target).relative_path_from(Pathname.new(source_dir))
      end

      def make_symlink(old_name, new_name)
        logger.debug(
          'Creating symlink',
          symlink: new_name,
          target: old_name.to_s,
          DRY_RUN: @options[:dry_run_mode],
        )
        File.symlink(old_name, new_name) unless @options[:dry_run_mode]
      end
    end
  end
end
