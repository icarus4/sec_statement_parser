module SecStatementParser

  module Debug

    LOG_LEVELS = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL', 'UNKNOWN']

    def init_logger(log_level='WARN')
      # Set default log level to WARN
      log_level = "WARN" unless LOG_LEVELS.include? log_level.upcase
      $log = Logger.new(STDOUT)
      eval("$log.level = Logger::#{log_level.upcase}")
    end
  end
end
