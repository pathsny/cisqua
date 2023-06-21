require 'logging'

Logging.logger.root.level = :debug

Logging.color_scheme(:colorful, {
                       levels: {
                         info: :green,
                         warn: :yellow,
                         error: :red,
                         fatal: %i[white on_red]
                       },
                       date: :cyan,
                       logger: :magenta
                     })

module Loggers
  PostProcessor = Logging.logger['PostProcessor']
  Renamer = Logging.logger['Renamer']
  Symlinker = Logging.logger['Symlinker']
  UDPClient = Logging.logger['UDPClient']
  CreateLinks = Logging.logger['CreateLinks']
  FindDuplicates = Logging.logger['FindDuplicates']
  NFOize = Logging.logger['NFOize']
  PlexAnidbIdize = Logging.logger['PlexAnidbIdize']
  BadFiles = Logging.logger['BadFiles']
  VideoFileMover = Logging.logger['VideoFileMover']

  def self.set_log_level_from_option(log_level_option)
    log_level = begin
      log_level_option.to_sym
    rescue StandardError
      :debug
    end
    log_level = :debug unless %i[debug info warn error fatal].include?(log_level)
    Logging.logger.root.level = log_level
  end

  def self.setup_log_file(log_file_path, parseable_logfile_path = nil)
    Logging.logger.root.remove_appenders('parseable_logfile', 'logfile')
    Logging.appenders.file(
      'logfile',
      filename: log_file_path,
      layout: Logging.layouts.pattern({ color_scheme: :colorful })
    )
    Logging.logger.root.add_appenders('logfile')
    return unless parseable_logfile_path

    Logging.appenders.file(
      'parseable_logfile',
      filename: parseable_logfile_path,
      layout: Logging.layouts.json(items: %w[timestamp level logger message pid])
    )
  end
end

Logging.appenders.stdout(
  'stdout',
  layout: Logging.layouts.pattern({ color_scheme: :colorful })
)

Loggers.setup_log_file(
  File.expand_path('../data/log/anidb.log', __dir__),
  File.expand_path('../data/log/anidb_json.log', __dir__)
)

# Logging.appenders.file('logfile',
#   :filename => File.expand_path('../../data/log/anidb.log', __FILE__),
#   :layout => ),
# )

# parseable_logfile = File.expand_path('../../data/log/anidb_json.log', __FILE__)

Logging.define_singleton_method(:parseable_logfile) { parseable_logfile }

Logging.logger.root.add_appenders 'stdout', 'logfile', 'parseable_logfile'
