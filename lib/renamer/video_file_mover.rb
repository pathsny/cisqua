module Cisqua
  module Renamer
    class VideoFileMover
      include SemanticLogger::Loggable

      def initialize(options)
        @options = options
        @symlinker = Symlinker.new(options)
      end

      # moves file to dst_dir.
      # options can be configured to create a new_name at destination or
      # symlink back to source.
      def process(src_file:, dst_dir:, **move_options)
        dst_file = generate_destination(src_file:, dst_dir:, **move_options)
        is_duplicate = is_duplicate_destination(src_file, dst_file)
        yield(is_duplicate) if block_given?
        return Response.duplicate(dst_file) if is_duplicate

        unless File.directory?(dst_dir)
          logger.debug(
            'Creating directory',
            dst_dir:,
            DRY_RUN: @options[:dry_run_mode],
          )
          FileUtils.mkdir_p(dst_dir) unless @options[:dry_run_mode]
        end
        move_file(src_file:, dst_file:, **move_options)
        @options[:subtitle_extensions].split.each do |ext|
          sub_src_file = swap_extension(src_file, ext)
          next unless File.exist?(sub_src_file)

          move_file(
            src_file: sub_src_file,
            dst_file: swap_extension(dst_file, ext),
            **move_options,
          )
        end
        Response.success(dst_file)
      end

      def move_directory_contents(src_dir:, dst_dir:, src_file_prefix:, dst_file_prefix:, **move_options)
        if File.exist?(dst_dir)
          logger.warn('Destination directory already exists. Not merging directories', dst_dir:)
          return false
        end

        unless File.exist?(src_dir)
          logger.warn('Source directory does not exist. Nothing to do', src_dir:)
          return false
        end
        FileUtils.mkdir_p(dst_dir)

        Dir.glob(File.join(src_dir, '*')).each do |src_file|
          basename = File.basename(src_file)
          if basename.start_with?(src_file_prefix)
            new_name = basename.sub(/^#{Regexp.escape(src_file_prefix)}/, dst_file_prefix)
            dst_file = File.join(dst_dir, new_name)
          else
            dst_file = File.join(dst_dir, basename)
          end
          move_file(src_file:, dst_file:, **move_options)
        end
        true
      end

      private

      def generate_destination(src_file:, dst_dir:, **move_options)
        ext = File.extname(src_file)
        new_name = move_options[:new_name] || File.basename(src_file, '.*')
        suffix = ''
        mk_dest = -> { File.join(dst_dir, new_name + suffix + ext) }
        dst_file = mk_dest.call
        while move_options[:unambiguous] && is_duplicate_destination(src_file, dst_file)
          suffix = ".#{suffix[1..].to_i + 1}"
          dst_file = mk_dest.call
        end
        dst_file
      end

      def swap_extension(file, ext)
        file.chomp(File.extname(file)) + ".#{ext}"
      end

      def is_duplicate_destination(src_file, dst_file)
        File.exist?(dst_file) && dst_file != src_file
      end

      # moves a file from `src_file` to `dst_file`.
      # Optionally generates a symlink back to src_file if specified with options
      def move_file(src_file:, dst_file:, **move_options)
        symlinks_to_update = []
        if move_options[:update_links_from] && !@options[:dry_run_mode]
          symlinks_to_update = symlink_for(src_file, move_options[:update_links_from])
          symlinks_to_update.each do |symlink|
            logger.debug(
              'removing old symlink',
              symlink:,
              target: src_file,
            )
            FileUtils.rm(symlink)
          end
        end
        logger.debug(
          'moving file',
          src: src_file,
          dest: dst_file,
          options: move_options,
          DRY_RUN: @options[:dry_run_mode],
        )
        FileUtils.mv(src_file, dst_file) unless @options[:dry_run_mode]
        if move_options[:symlink_source] && src_file != dst_file
          @symlinker.relative(dst_file, src_file)
        end
        symlinks_to_update.each do |symlink|
          logger.debug(
            'restoring symlink',
            symlink:,
            target: dst_file,
          )
          @symlinker.relative(dst_file, symlink)
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
