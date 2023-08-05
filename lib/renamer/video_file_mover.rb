module Cisqua
  module Renamer
    class VideoFileMover
      include SemanticLogger::Loggable

      def initialize(options)
        @options = options
        @symlinker = Symlinker.new(options)
      end

      # moves file to location.
      # options can be configured to create a new_name at destination or
      # symlink back to source.
      def process(old_path, location, move_options = {})
        destination = generate_destination(old_path, location, move_options)
        return Response.duplicate(destination) if is_duplicate_destination(old_path, destination)

        unless File.directory?(location)
          logger.debug(
            'Creating directory',
            location:,
            DRY_RUN: @options[:dry_run_mode],
          )
          FileUtils.mkdir_p(location) unless @options[:dry_run_mode]
        end
        move_file(old_path, destination, move_options)
        @options[:subtitle_extensions].split.each do |ext|
          sub_path = swap_extension(old_path, ext)
          move_file(sub_path, swap_extension(destination, ext), move_options) if
            File.exist?(sub_path)
        end
        Response.success(destination)
      end

      private

      def generate_destination(old_path, location, move_options)
        ext = File.extname(old_path)
        new_name = move_options[:new_name] || File.basename(old_path, '.*')
        suffix = ''
        mk_dest = -> { File.join(location, new_name + suffix + ext) }
        destination = mk_dest.call
        while move_options[:unambiguous] && is_duplicate_destination(old_path, destination)
          suffix = ".#{suffix[1..].to_i + 1}"
          destination = mk_dest.call
        end
        destination
      end

      def swap_extension(file, ext)
        file.chomp(File.extname(file)) + ".#{ext}"
      end

      def is_duplicate_destination(old_path, destination)
        File.exist?(destination) && destination != old_path
      end

      # moves a file from `old_path` to `new_path`.
      # Optionally generates a symlink back to old_path if specified with options
      def move_file(old_path, new_path, move_options)
        logger.debug(
          'moving file',
          dest: new_path,
          options: move_options,
          DRY_RUN: @options[:dry_run_mode],
        )
        FileUtils.mv(old_path, new_path) unless @options[:dry_run_mode]
        if @options.to_h.merge(move_options)[:symlink_source] && old_path != new_path
          @symlinker.relative(new_path, old_path)
        end
        return unless move_options[:update_links_from]

        symlink_for(old_path, move_options[:update_links_from]).each do |old_link|
          logger.debug(
            'removing old symlink',
            symlink: old_link,
            target: old_path,
          )
          FileUtils.rm(old_link) unless @options[:dry_run_mode]
          @symlinker.relative(new_path, old_link)
        end
      end

      def symlink_for(target, basedir)
        Dir.glob(File.join(basedir.to_s, '**/*.*'), File::FNM_CASEFOLD).select do |n|
          File.symlink?(n) &&
            File.expand_path(File.readlink(n), File.dirname(n)) == target
        end
      end
    end
  end
end
