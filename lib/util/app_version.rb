require 'json'
require 'open3'
require 'timeout'

module Cisqua
  class AppVersion
    FILE_PATH = File.join(ROOT_FOLDER, 'config', 'version.json')
    CACHE_TTL_SECONDS = 30

    class << self
      def fetch
        file_data = read_file
        return file_data.merge(source: 'static') if file_data[:valid]

        cached = cached_data
        return cached if cached

        git_data = read_git
        if git_data
          cache(git_data)
          return git_data
        end

        { valid: false, source: 'unknown' }
      end

      private

      def read_file
        return { valid: false } unless File.exist?(FILE_PATH)

        raw = JSON.parse(File.read(FILE_PATH))
        normalize(raw)
      rescue StandardError
        { valid: false }
      end

      def normalize(data)
        symbolized = data.transform_keys { |k| k.to_s.downcase.to_sym }
        symbolized[:valid] = symbolized[:valid] == true
        symbolized
      end

      def read_git
        commit = git('rev-parse', 'HEAD')
        commit_time = git('log', '-1', '--format=%cI')
        branch = git('rev-parse', '--abbrev-ref', 'HEAD')

        return nil if commit.nil? || commit_time.nil?

        {
          valid: true,
          commit:,
          branch:,
          commit_time:,
          source: 'git',
        }
      end

      def git(*args)
        Timeout.timeout(2) do
          stdout, _stderr, status = Open3.capture3('git', '-C', ROOT_FOLDER, *args)
          return nil unless status.success?

          output = stdout.strip
          output.empty? ? nil : output
        end
      rescue StandardError
        nil
      end

      def cached_data
        return nil if @cache_data.nil? || @cache_at.nil?
        return nil if (Time.now - @cache_at) > CACHE_TTL_SECONDS

        @cache_data
      end

      def cache(data)
        @cache_data = data
        @cache_at = Time.now
      end
    end
  end
end
