# frozen_string_literal: true

require "dip/errors"
require "dip/config"
require "dip/environment"
require 'logger'

module Dip
  def self.logger
    @logger ||= Logger.new(STDOUT).tap do |log|
      log.level = Logger::INFO
      log.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity}: #{msg}\n"
      end
    end
  end

  class << self
    def config
      @config ||= Dip::Config.new
    end


    def env
      @env ||= Dip::Environment.new(config.exist? ? config.environment : {})
    end

    def bin_path
      $PROGRAM_NAME.start_with?("./") ? File.expand_path($PROGRAM_NAME) : "dip"
    end

    def home_path
      @home_path ||= File.expand_path(ENV.fetch("DIP_HOME", "~/.dip"))
    end

    %w[test debug].each do |key|
      define_method("#{key}?") do
        ENV["DIP_ENV"] == key
      end
    end

    def reset!
      @config = nil
      @env = nil
    end
  end
end
