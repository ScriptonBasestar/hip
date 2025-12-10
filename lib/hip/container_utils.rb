# frozen_string_literal: true

# @file: lib/hip/container_utils.rb
# @purpose: Centralized Docker container status checking utilities
# @flow: Commands (Provision, DockerComposeRunner) -> ContainerUtils -> docker compose ps
# @dependencies: Hip::Commands::Compose, Hip::DebugLogger, Hip::ComposeFileParser
# @key_methods: any_containers_running?, service_running_project, detect_container_name_usage, warn_container_name_usage

require "json"

module Hip
  # Centralized utilities for Docker container status checking
  # Consolidates duplicate container detection logic from provision.rb
  # and docker_compose_runner.rb
  #
  # @example Check if any containers are running
  #   Hip::ContainerUtils.any_containers_running?
  #
  # @example Get project name for a running service
  #   project = Hip::ContainerUtils.service_running_project("app")
  #
  # @example Detect container_name usage and show warning
  #   Hip::ContainerUtils.warn_container_name_usage
  module ContainerUtils
    # Cache TTL in seconds for container status checks
    CACHE_TTL = 2

    class << self
      # Check if any containers are running for this project
      #
      # @return [Boolean] true if at least one container is running
      def any_containers_running?
        containers = fetch_container_statuses
        return false if containers.empty?

        running_count = containers.count { |c| c["State"]&.downcase == "running" }
        DebugLogger.log("Found #{running_count} running container(s)")
        running_count > 0
      end

      # Get the project name for a running service container
      # Used to detect if a service is already running and switch run -> exec
      #
      # @param service_name [String] The service name to check
      # @return [String, nil] Project name if running, nil otherwise
      def service_running_project(service_name)
        cache_key = "container_project:#{service_name}"

        # Check cache first
        if cache_valid?(cache_key)
          cached_value = cache_get(cache_key)
          DebugLogger.log("Using cached container status for \"#{service_name}\"")
          return cached_value
        end

        # Fetch container status for this specific service
        containers = fetch_container_statuses(service_name)

        if containers.empty?
          DebugLogger.log("No container found for service \"#{service_name}\"")
          cache_set(cache_key, nil)
          return nil
        end

        # Check first container (could be multiple replicas)
        container = containers.first
        state = container["State"]
        project = container["Project"]

        result = if state&.downcase == "running"
          DebugLogger.log("Container \"#{container["Name"]}\" state: #{state}, project: #{project}")
          project
        else
          DebugLogger.log("Container found but not running: state=#{state}")
          nil
        end

        cache_set(cache_key, result)
        result
      end

      # Clear the container status cache
      # Useful for testing or when containers have been modified
      def clear_cache
        @cache = {}
        @session_cache = {}
      end

      # Detect container_name usage in compose files
      # Returns details about services with fixed container names
      #
      # @return [Hash, nil] Detection result or nil if no container_name found
      #   - :services [Hash<String, String>] service_name => container_name
      #   - :project_name [String, nil] project_name from hip.yml if set
      #   - :compose_files [Array<String>] paths to compose files
      def detect_container_name_usage
        cache_key = "container_name_usage"
        return session_cache_get(cache_key) if session_cache_has?(cache_key)

        result = check_container_name_usage
        session_cache_set(cache_key, result)
        result
      end

      # Display warning if container_name is detected in compose files
      # Warning is always shown (unless HIP_IGNORE_CONFLICTS is set)
      #
      # @return [Boolean] true if warning was displayed
      def warn_container_name_usage
        detection = detect_container_name_usage
        return false unless detection && detection[:services].any?

        warn format_container_name_warning(detection)
        true
      end

      private

      # Check compose files for container_name usage
      def check_container_name_usage
        compose_config = Hip.config.compose
        return nil if compose_config.nil? || compose_config.empty?

        require_relative "compose_file_parser"
        parser = ComposeFileParser.new(compose_config)
        services_with_names = parser.services_with_container_name

        return nil if services_with_names.empty?

        {
          services: services_with_names,
          project_name: compose_config[:project_name],
          compose_files: parser.compose_files.map(&:to_s)
        }
      end

      # Format the warning message for container_name detection
      def format_container_name_warning(detection)
        lines = []
        lines << "=" * 80
        lines << "WARNING: container_name detected in docker-compose files"
        lines << "=" * 80
        lines << ""

        if detection[:project_name]
          lines << "Hip project_name: \"#{detection[:project_name]}\""
        end

        lines << "Services with fixed container_name:"
        detection[:services].each do |service, name|
          lines << "  - #{service}: \"#{name}\""
        end

        lines << ""
        if detection[:project_name]
          lines << "Problem:"
          lines << "  - \"container name already in use\" errors may occur when running"
          lines << "    multiple instances or restarting containers"
          lines << ""
          lines << "Note: Hip auto-detection (run -> exec) works normally with container_name."
        else
          lines << "Note: Fixed container names may cause \"container name already in use\" errors"
          lines << "when running multiple instances. Hip auto-detection (run -> exec) works normally."
        end
        lines << ""
        lines << "Options:"
        lines << "  1. Remove container_name from docker-compose.yml (recommended)"
        lines << "  2. Set HIP_IGNORE_CONFLICTS=1 to suppress this warning"

        lines << "=" * 80
        lines.join("\n")
      end

      # Session-level cache (no TTL, cleared only on reset)
      def session_cache
        @session_cache ||= {}
      end

      def session_cache_has?(key)
        session_cache.key?(key)
      end

      def session_cache_get(key)
        session_cache[key]
      end

      def session_cache_set(key, value)
        session_cache[key] = value
      end

      # Fetch container statuses from docker compose ps
      #
      # @param service_name [String, nil] Optional service name filter
      # @return [Array<Hash>] Array of container info hashes
      def fetch_container_statuses(service_name = nil)
        require_relative "commands/compose"

        args = ["ps", "--format", "json"]
        args << service_name if service_name

        compose = Commands::Compose.new(*args)
        cmd = compose.build_command

        DebugLogger.log("Checking container status: #{cmd.join(" ")}")
        output = `#{cmd.shelljoin} 2>/dev/null`.strip

        return [] if output.empty?

        # docker compose ps --format json outputs one JSON object per line
        output.lines.map do |line|
          JSON.parse(line.strip)
        end
      rescue JSON::ParserError => e
        DebugLogger.log_error("fetch_container_statuses", e)
        []
      rescue => e
        DebugLogger.log_error("fetch_container_statuses", e)
        []
      end

      # Time-based cache for container detection results
      def cache
        @cache ||= {}
      end

      def cache_valid?(key)
        return false unless cache[key]

        cached_at, _value = cache[key]
        if Time.now - cached_at < CACHE_TTL
          true
        else
          cache.delete(key)
          false
        end
      end

      def cache_get(key)
        return nil unless cache[key]

        _cached_at, value = cache[key]
        value
      end

      def cache_set(key, value)
        cache[key] = [Time.now, value]
      end
    end
  end
end
