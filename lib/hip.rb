# frozen_string_literal: true

# @file: lib/hip.rb
# @purpose: Hip module entry point, provides global state access
# @flow: exe/hip -> require 'hip' -> Hip.config, Hip.env, Hip.logger
# @dependencies: hip/errors, hip/config, hip/environment, logger
# @key_methods: config, env, logger, bin_path, home_path, reset!

require "hip/errors"
require "hip/config"
require "hip/environment"
require "logger"

module Hip
  def self.logger
    @logger ||= Logger.new($stdout).tap do |log|
      log.level = Logger::INFO
      log.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity}: #{msg}\n"
      end
    end
  end

  class << self
    def config
      @config ||= Hip::Config.new
    end

    def env
      @env ||= Hip::Environment.new(config.exist? ? config.environment : {})
    end

    def bin_path
      $PROGRAM_NAME.start_with?("./") ? File.expand_path($PROGRAM_NAME) : "hip"
    end

    def home_path
      @home_path ||= File.expand_path(ENV.fetch("HIP_HOME", "~/.hip"))
    end

    %w[test debug].each do |key|
      define_method("#{key}?") do
        ENV["HIP_ENV"] == key
      end
    end

    def reset!
      @config = nil
      @env = nil
    end
  end
end
