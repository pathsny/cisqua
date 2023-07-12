module Renamer
  class Symlinker
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
        Loggers::Symlinker.debug("Creating #{source_dir}. #{dry_run}")
        FileUtils.mkdir_p(source_dir) unless @options[:dry_run_mode]
      end
      (Pathname.new target).relative_path_from(Pathname.new(source_dir))
    end

    def make_symlink(old_name, new_name)
      dry_run = @options[:dry_run_mode] ? ' DRY RUN' : ''
      Loggers::Symlinker.debug(
        "Creating symlink #{new_name} pointing to #{old_name}.#{dry_run}",
      )
      File.symlink(old_name, new_name) unless @options[:dry_run_mode]
    end
  end
end
