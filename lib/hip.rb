# frozen_string_literal: true

# @file: lib/hip.rb
# @purpose: Hip module entry point, provides global state access
# @flow: exe/hip -> require 'hip' -> Hip.config, Hip.env, Hip.logger
# @dependencies: hip/errors, hip/config, hip/environment, logger
# @key_methods: config, env, logger, bin_path, home_path, reset!

require "hip/errors"
require "hip/config"
require "hip/environment"
require "hip/debug_logger"
require "logger"

module Hip
  def self.logger
    @logger ||= Logger.new($stdout).tap do |log|
      log.level = debug? ? Logger::DEBUG : Logger::INFO
      log.formatter = proc do |severity, datetime, progname, msg|
        if debug?
          "[#{datetime}] #{severity}: #{msg}\n"
        elsif severity != "DEBUG"
          # Simpler format for non-debug mode
          "#{msg}\n"
        end
      end
    end
  end

  class << self
    def config
      @config ||= Hip::Config.new
    end

    def env
      @env ||= Hip::Environment.new(
        config.exist? ? config.environment : {},
        env_file_config: config.exist? ? config.env_file : nil,
        base_path: config.exist? ? config.file_path.parent : nil
      )
    end

    def bin_path
      $PROGRAM_NAME.start_with?("./") ? File.expand_path($PROGRAM_NAME) : "hip"
    end

    def home_path
      @home_path ||= File.expand_path(ENV.fetch("HIP_HOME", "~/.hip"))
    end

    %w[test debug].each do |key|
      define_method("#{key}?") do
        ENV["HIP_ENV"] == key || (key == "debug" && ENV["HIP_DEBUG"] == "1")
      end
    end

    def reset!
      @config = nil
      @env = nil
    end
  end
end
