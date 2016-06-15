require 'logging'

# Logging.logger.root.level = $DEBUG ? :debug : :info
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

Logging.appenders.file('parseable_logfile',
  :filename => File.expand_path('../../log/anidb_json.log', __FILE__),
  :layout => Logging.layouts.json
)

Logging.logger.root.add_appenders 'stdout', 'logfile', 'parseable_logfile'

module Loggers
  Web = Logging.logger['Web']
  AnidbResourceFetcher = Logging.logger['AnidbResourceFetcher']
  FeedProcessor = Logging.logger['FeedProcessor']
  DB = Logging.logger['DB']
  Concurrent = Logging.logger['Concurrent']
end
