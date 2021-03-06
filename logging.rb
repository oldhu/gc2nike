require 'logger'

class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t| t.write(*args)}
  end

  def close
    @targets.each(&:close)
  end
end

module Logging
  # This is the magical bit that gets mixed into your classes
  def logger
    Logging.logger
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    return @logger unless @logger.nil?
    log_file = Logger::LogDevice.new('gc2nike.log', :shift_age => 10, :shift_size => 1024000)
    @logger = Logger.new MultiIO.new(STDOUT, log_file)
    @logger.sev_threshold = Logger::INFO
    return @logger
  end
end