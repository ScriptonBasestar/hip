# frozen_string_literal: true

# @file: lib/hip/commands/runners/docker_compose_runner.rb
# @purpose: Execute commands via Docker Compose (run/exec/up methods)
# @flow: Run -> DockerComposeRunner.execute -> Compose command construction
# @dependencies: Base, Hip::Commands::Compose
# @key_methods: execute (builds compose args with env, ports, profiles)
# @config_keys: command[:service], command[:compose][:method], command[:compose][:run_options]

require_relative "base"
require_relative "../compose"

module Hip
  module Commands
    module Runners
      class DockerComposeRunner < Base
        # Cache container detection results for 2 seconds to avoid
        # repeated docker compose ps calls within same execution context
        CONTAINER_CACHE_TTL = 2

        def execute
          Hip.logger.debug "Hip.Commands.Runners.DockerComposeRunner#execute >>>>>>>>>>"
          Hip.logger.debug "Hip.Commands.Runners.DockerComposeRunner#execute command: #{command}"

          # Auto-detect if container is running and switch to exec
          auto_detect_compose_method!

          Hip.logger.debug "Hip.Commands.Runners.DockerComposeRunner#execute compose_profiles: #{compose_profiles}"
          Hip.logger.debug "Hip.Commands.Runners.DockerComposeRunner#execute compose_arguments: #{compose_arguments}"

          # Build compose command with detected project name if needed
          compose_cmd_args = []
          compose_cmd_args.concat(compose_profiles)
          compose_cmd_args.concat(detected_project_args) if @detected_project_name
          compose_cmd_args << command[:compose][:method]
          compose_cmd_args.concat(compose_arguments)

          Commands::Compose.new(
            *compose_cmd_args,
            shell: command[:shell]
          ).execute
        end

        private

        def compose_profiles
          return [] if command[:compose][:profiles].empty?

          update_command_for_profiles

          command[:compose][:profiles].each_with_object([]) do |profile, argv|
            argv.concat(["--profile", profile])
          end
        end

        def compose_arguments
          compose_argv = command[:compose][:run_options].dup

          if command[:compose][:method] == "run"
            Hip.logger.debug "Hip.Commands.Runners.DockerComposeRunner#compose_arguments - if run"
            compose_argv.concat(run_vars)
            compose_argv.concat(published_ports)
            compose_argv << "--rm"
          elsif command[:compose][:method] == "exec"
            # default exec
            Hip.logger.debug "Hip.Commands.Runners.DockerComposeRunner#compose_arguments - elsif exec"
          else
            # none
            Hip.logger.debug "Hip.Commands.Runners.DockerComposeRunner#compose_arguments - else none"
          end

          compose_argv << "--user #{command.fetch(:user)}" if command[:user]
          compose_argv << "--workdir #{command.fetch(:workdir)}" if command[:workdir]

          compose_argv << command.fetch(:service)

          unless (cmd = command[:command]).empty?
            if command[:shell]
              compose_argv << cmd
            else
              compose_argv.concat(cmd.shellsplit)
            end
          end

          compose_argv.concat(command_args)

          compose_argv
        end

        def run_vars
          run_vars = Hip::RunVars.env
          return [] unless run_vars

          run_vars.map { |k, v| ["-e", "#{k}=#{Shellwords.escape(v)}"] }.flatten
        end

        def published_ports
          publish = options[:publish]

          if publish.respond_to?(:each)
            publish.map { |p| "--publish=#{p}" }
          else
            []
          end
        end

        def update_command_for_profiles
          # NOTE: When using profiles, the method is always `up`.
          #       This is because `docker compose` does not support profiles
          #       for other commands. Also, run options need to be removed
          #       because they are not supported by `up`.
          command[:compose][:method] = "up"
          command[:command] = ""
          command[:compose][:run_options] = []
        end

        def auto_detect_compose_method!
          # Auto-detect if container is already running and switch from 'run' to 'exec'
          #
          # This prevents container name conflicts when:
          # - Container already exists with same name
          # - Project name in hip.yml differs from actual running container's project
          # - User runs commands while containers are still up
          #
          # Behavior:
          # - Only operates on 'run' method (exec/up unchanged)
          # - Returns early if no service specified
          # - On detection success: switches to 'exec', removes incompatible flags
          # - On detection failure: keeps 'run' method (safe fallback)
          return unless command[:compose][:method] == "run"

          service_name = command[:service]
          return unless service_name

          # Check if container is already running and get its actual project name
          actual_project_name = detect_running_container_project(service_name)
          if actual_project_name
            Hip.logger.debug "Container for service \"#{service_name}\" is running under project \"#{actual_project_name}\", switching to exec"
            command[:compose][:method] = "exec"
            # exec doesn't support --rm and some run options
            command[:compose][:run_options].reject! { |opt| opt.include?("--rm") }
            # Override project name with actual running container's project
            @detected_project_name = actual_project_name
          end
        end

        def detect_running_container_project(service_name)
          # Use docker compose ps to check if service container is running
          # and return the actual project name
          #
          # Error Handling:
          # - Returns nil on any error (graceful degradation to 'run' mode)
          # - Expected error scenarios:
          #   1. Docker daemon not running → StandardError → nil
          #   2. Compose files not found → empty output → nil
          #   3. Service doesn't exist → empty output → nil
          #   4. Invalid JSON response → JSON::ParserError → nil
          #   5. Network/permission issues → StandardError → nil
          # - All errors logged at debug level (not user-facing)
          #
          # Performance: Results cached for CONTAINER_CACHE_TTL seconds
          cache_key = "container_project:#{service_name}"
          if container_cache_has?(cache_key)
            cached = container_cache_get(cache_key)
            Hip.logger.debug "Using cached container status for \"#{service_name}\""
            return cached
          end

          ps_cmd = build_compose_command(["ps", "--format", "json", service_name])

          Hip.logger.debug "Checking container status: #{ps_cmd.join(" ")}"

          output = `#{ps_cmd.shelljoin} 2>/dev/null`.strip

          # docker compose ps --format json outputs one JSON object per line
          if output.empty?
            Hip.logger.debug "No container found for service \"#{service_name}\""
            container_cache_set(cache_key, nil)
            return nil
          end

          # Parse first line as JSON (could be multiple containers, we check the first)
          require "json"
          container_info = JSON.parse(output.lines.first)
          state = container_info["State"]
          project = container_info["Project"]

          result = if state&.downcase == "running"
            Hip.logger.debug "Container \"#{container_info["Name"]}\" (#{container_info["ID"]}) state: #{state}, project: #{project}"
            project
          else
            Hip.logger.debug "Container found but not running: state=#{state}"
            nil
          end

          # Cache the result
          container_cache_set(cache_key, result)
          result
        rescue JSON::ParserError => e
          # Malformed JSON from docker compose ps (rare but possible)
          Hip.logger.debug "Failed to parse container status JSON: #{e.message}"
          nil
        rescue => e
          # Covers: Errno::ENOENT (docker not found), command execution failures, etc.
          Hip.logger.debug "Error checking container status: #{e.message}"
          nil
        end

        def build_compose_command(args)
          # Build compose command exactly like Hip::Commands::Compose#execute
          #
          # Constructs docker compose command with proper file paths and options:
          # - Base: ["docker", "compose"]
          # - Files: --file /path/to/compose.yml (from hip.yml compose.files)
          # - Project: --project-name <name> (only if @detected_project_name set)
          # - Args: additional arguments (e.g., ["ps", "--format", "json"])
          cmd = ["docker", "compose"]
          cmd.concat(compose_file_args)
          cmd.concat(compose_project_args)
          cmd.concat(args)
          cmd
        end

        def compose_file_args
          files = Hip.config.compose[:files]
          return [] unless files.is_a?(Array)

          files.each_with_object([]) do |file_path, memo|
            file_path = Pathname.new(file_path)
            file_path = Hip.config.file_path.parent.join(file_path).expand_path if file_path.relative?
            next unless file_path.exist?

            memo << "--file"
            memo << file_path.to_s
          end
        end

        def compose_project_args
          # Include project name from config for accurate container detection
          # This is necessary because docker compose ps without --project-name
          # fails to find containers when executed from a different directory
          project_name = Hip.config.compose[:project_name]
          return [] unless project_name

          ["--project-name", project_name]
        end

        def detected_project_args
          # Return project name args for detected running container
          ["--project-name", @detected_project_name]
        end

        # Simple time-based cache for container detection results
        # Prevents redundant docker compose ps calls within short time windows
        def container_cache
          @container_cache ||= {}
        end

        def container_cache_has?(key)
          return false unless container_cache[key]

          cached_at, _value = container_cache[key]
          if Time.now - cached_at < CONTAINER_CACHE_TTL
            true
          else
            container_cache.delete(key)
            false
          end
        end

        def container_cache_get(key)
          return nil unless container_cache[key]

          _cached_at, value = container_cache[key]
          value
        end

        def container_cache_set(key, value)
          container_cache[key] = [Time.now, value]
        end
      end
    end
  end
end
