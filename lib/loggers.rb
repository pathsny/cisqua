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
  Web = Logging.logger['Web']
  AnidbHTTP = Logging.logger['AnidbHTTP']
  FeedProcessor = Logging.logger['FeedProcessor']
  DB = Logging.logger['DB']
  Concurrent = Logging.logger['Concurrent']
  LogTailer = Logging.logger['LogTailer'] 
  PostProcessor = Logging.logger['PostProcessor']
  Renamer = Logging.logger['Renamer']
  UDPClient = Logging.logger['UDPClient']
end
