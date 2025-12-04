# frozen_string_literal: true

# @file: lib/hip/debug_logger.rb
# @purpose: Centralized debug logging utility to reduce code duplication
# @flow: Hip modules -> DebugLogger.method_entry/execution/context -> unified output
# @dependencies: Hip.logger, Hip.debug?
# @key_methods: method_entry, log_execution, log_context

module Hip
  # Centralized debug logging utility
  # Replaces scattered debug logging patterns throughout the codebase
  #
  # @example Method entry logging
  #   DebugLogger.method_entry("ClassName#method_name", arg1: value1, arg2: value2)
  #
  # @example Command execution logging
  #   DebugLogger.log_execution(command, via: "exec", env: env_vars)
  #
  # @example Context logging
  #   DebugLogger.log_context("operation_name", key1: value1, key2: value2)
  module DebugLogger
    class << self
      # Log method entry with optional context
      #
      # @param method_name [String] Full method name (e.g., "ClassName#method_name")
      # @param context [Hash] Key-value pairs to log
      def method_entry(method_name, **context)
        return unless Hip.debug?

        Hip.logger.debug "[#{method_name}] >>>>>>>>>>"
        context.each do |key, value|
          Hip.logger.debug "[#{method_name}] #{key}: #{value.inspect}"
        end
      end

      # Log command execution with formatted output
      #
      # @param command [String, Array] Command to execute
      # @param via [String] Execution method (e.g., "exec", "system")
      # @param details [Hash] Additional details to display
      def log_execution(command, via: nil, **details)
        return unless Hip.debug?

        cmd_str = command.is_a?(Array) ? command.join(" ") : command
        via_str = via ? " (via #{via})" : ""

        output = StringIO.new
        output.puts "\n" + "=" * 80
        output.puts "🔍 DEBUG: Executing command#{via_str}"
        output.puts "=" * 80
        output.puts "Command: #{cmd_str}"
        details.each { |k, v| output.puts "#{k}: #{v.inspect}" }
        output.puts "=" * 80 + "\n"

        warn output.string
      end

      # Log context information for debugging
      #
      # @param operation [String] Operation being performed
      # @param context [Hash] Key-value pairs to log
      def log_context(operation, **context)
        return unless Hip.debug?

        Hip.logger.debug "[#{operation}] Context:"
        context.each do |key, value|
          Hip.logger.debug "  #{key}: #{value.inspect}"
        end
      end

      # Log a simple debug message
      #
      # @param message [String] Message to log
      def log(message)
        return unless Hip.debug?

        Hip.logger.debug message
      end

      # Log error information
      #
      # @param operation [String] Operation that failed
      # @param error [Exception] Error that occurred
      # @param context [Hash] Additional context
      def log_error(operation, error, **context)
        Hip.logger.debug "[#{operation}] Error: #{error.message}"
        context.each do |key, value|
          Hip.logger.debug "[#{operation}] #{key}: #{value.inspect}"
        end
      end
    end
  end
end
