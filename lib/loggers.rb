require 'logging'

Logging.logger.root.level = :debug

default_scheme = Logging::ColorScheme[:default]

Logging.color_scheme(:colorful, {
  :levels => {
    :info  => :green,
    :warn  => :yellow,
    :error => :red,
    :fatal => [:white, :on_red]
  },
  :date => :cyan,
  :logger => :magenta,
})

Logging.appenders.stdout(
  'stdout',
  :layout => Logging.layouts.pattern({:color_scheme => :colorful}),

)
Logging.appenders.file('logfile',
  :filename => File.expand_path('../../log/anidb.log', __FILE__),
  :layout => Logging.layouts.pattern({}),
)

parseable_logfile = File.expand_path('../../log/anidb_json.log', __FILE__)

Logging.appenders.file('parseable_logfile',
  :filename => parseable_logfile,
  :layout => Logging.layouts.json(:items => %w[timestamp level logger message pid]),
)

Logging.define_singleton_method(:parseable_logfile) { parseable_logfile }

Logging.logger.root.add_appenders 'stdout', 'logfile', 'parseable_logfile'

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
    log_level = log_level_option.to_sym rescue :debug
    unless [:debug, :info, :warn, :error, :fatal].include?(log_level)
      log_level = :debug
    end
    Logging.logger.root.level = log_level
  end
end
