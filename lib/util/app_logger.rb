require 'logger'

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

    def self.rack_logger
      return @rack_logger unless @rack_logger.nil?

      rack_log_path = Pathname.new(log_file).sub_ext('.rack.log').to_path
      rack_log_file = File.new(rack_log_path, 'a+')
      rack_log_file.sync = true

      @rack_logger = Logger.new(rack_log_file)
    end

    def self.setup_logging(test_mode: nil)
      @test_mode = test_mode unless test_mode.nil?

      SemanticLogger.clear_appenders!
      current_formatter = formatter(test_mode: @test_mode)

      SemanticLogger.add_appender(
        file_name: log_file,
        formatter: current_formatter,
        level: :info,
      )
      SemanticLogger.add_appender(
        file_name: debug_log_file,
        formatter: current_formatter,
        level: :debug,
      )

      return if @stdout_logging_disabled

      SemanticLogger.add_appender(
        io: $stdout,
        formatter: current_formatter,
        level: @stdout_log_level || (test_mode ? :debug : :info),
      )
    end

    def self.formatter(test_mode: false)
      color_map = SemanticLogger::Formatters::Color::ColorMap.new(
        warn: SemanticLogger::AnsiColors::YELLOW,
      )
      ap = { multiline: true, ruby19_syntax: true }

      if test_mode
        @test_formatter ||= TestLogFormatter.new(ap:, color_map:, precision: 2)
      else
        @formatter ||= AppLogFormatter.new(ap:, color_map:, precision: 2)
      end
    end

    class AppLogFormatter < SemanticLogger::Formatters::Color
      def pid; end
    end

    class TestLogFormatter < AppLogFormatter
      def call(log, logger)
        "🧪 [TEST] #{super}"
      end
    end
  end

  SemanticLogger.default_level = :debug
  AppLogger.setup_logging
end
