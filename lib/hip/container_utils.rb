# frozen_string_literal: true

# @file: lib/hip/container_utils.rb
# @purpose: Centralized Docker container status checking utilities
# @flow: Commands (Provision, DockerComposeRunner) -> ContainerUtils -> docker compose ps
# @dependencies: Hip::Commands::Compose, Hip::DebugLogger
# @key_methods: any_containers_running?, service_running_project

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
      end

      private

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
