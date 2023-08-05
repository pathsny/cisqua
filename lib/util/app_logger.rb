module Cisqua
  module AppLogger
    def self.log_level=(log_level)
      return if @stdout_log_level == log_level

      @stdout_log_level = log_level
      setup_logging
    end

    def self.log_file=(log_file)
      @log_file = log_file
      setup_logging
    end

    def self.disable_stdout_logging
      @stdout_logging_disabled = true
      setup_logging
    end

    def self.log_file
      @log_file || File.join(DATA_FOLDER, 'log', 'anidb.log')
    end

    def self.debug_log_file
      Pathname.new(log_file).sub_ext('.debug.log').to_path
    end

    def self.setup_logging
      SemanticLogger.clear_appenders!
      SemanticLogger.add_appender(
        file_name: log_file,
        formatter:,
        level: :info,
      )
      SemanticLogger.add_appender(
        file_name: debug_log_file,
        formatter:,
        level: :debug,
      )

      return if @stdout_logging_disabled

      SemanticLogger.add_appender(
        io: $stdout,
        formatter:,
        level: @stdout_log_level,
      )
    end

    def self.formatter
      color_map = SemanticLogger::Formatters::Color::ColorMap.new(
        warn: SemanticLogger::AnsiColors::YELLOW,
      )
      ap = { multiline: true, ruby19_syntax: true }
      @formatter ||= AppLogFormatter.new(ap:, color_map:, precision: 2)
    end

    class AppLogFormatter < SemanticLogger::Formatters::Color
      def pid; end
    end
  end

  SemanticLogger.default_level = :debug
  AppLogger.setup_logging
end
