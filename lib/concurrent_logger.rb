require_relative './loggers'
require 'concurrent-edge'

Concurrent.global_logger = Loggers::Concurrent