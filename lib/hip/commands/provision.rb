# frozen_string_literal: true

require "shellwords"
require_relative "../command"

module Hip
  module Commands
    class Provision < Hip::Command
      def initialize(argv = [])
        @argv = argv
      end

      def execute
        Hip.logger.debug "Hip.Commands.Provision#execute >>>>>>>"
        provision_key = @argv.first || :default
        Hip.logger.debug "Hip.Commands.Provision #{Hip.config.provision}"

        # If provision is empty or key not found, just return without error
        return if Hip.config.provision.empty?

        commands = Hip.config.provision[provision_key.to_sym]

        if commands.nil?
          raise Hip::Error, "Provision key '#{provision_key}' not found!"
        end

        # Auto-start containers if not running
        ensure_containers_running

        commands.each do |command|
          execute_command(command)
        end

        # Auto-generate Claude Code integration files after successful provision
        auto_generate_claude_files
      end

      private

      def ensure_containers_running
        # Check if any containers are running for this project
        # If not, automatically run `hip up -d --wait`
        Hip.logger.debug "Checking if containers are running..."

        unless any_containers_running?
          Hip.logger.info "No containers running. Starting containers with 'hip up -d --wait'..."
          puts "⚙️  Starting containers before provisioning..."
          puts ""

          # Use Compose command to start containers
          require_relative "compose"
          compose_args = ["up", "-d", "--wait"]
          Commands::Compose.new(*compose_args).execute

          puts ""
          Hip.logger.info "Containers started successfully"
        else
          Hip.logger.debug "Containers already running, proceeding with provision"
        end
      end

      def any_containers_running?
        # Use docker compose ps to check if any containers are running
        # Returns true if at least one container is in "running" state
        #
        # This is a simple check - we don't need to verify specific services,
        # just ensure that the docker compose stack is up
        ps_cmd = build_compose_ps_command

        Hip.logger.debug "Checking container status: #{ps_cmd.join(" ")}"

        output = `#{ps_cmd.shelljoin} 2>/dev/null`.strip

        if output.empty?
          Hip.logger.debug "No containers found"
          return false
        end

        # Parse JSON output and check for running containers
        require "json"
        running_count = output.lines.count do |line|
          container_info = JSON.parse(line)
          container_info["State"]&.downcase == "running"
        end

        Hip.logger.debug "Found #{running_count} running container(s)"
        running_count > 0
      rescue JSON::ParserError => e
        Hip.logger.debug "Failed to parse container status: #{e.message}"
        false
      rescue => e
        Hip.logger.debug "Error checking container status: #{e.message}"
        false
      end

      def build_compose_ps_command
        # Build docker compose ps command with proper file paths and project name
        cmd = ["docker", "compose"]
        cmd.concat(compose_file_args)
        cmd.concat(compose_project_args)
        cmd.concat(["ps", "--format", "json"])
        cmd
      end

      def compose_file_args
        # Get compose files from config
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
        # Get project name from config
        project_name = Hip.config.compose[:project_name]
        return [] unless project_name

        ["--project-name", project_name]
      end

      def execute_command(command)
        case command
        when String
          # Legacy string format: raw shell command
          Hip.logger.debug "Executing raw command: #{command}"
          exec_subprocess(command)
        when Hash
          # Structured command format
          Hip.logger.debug "Executing structured command: #{command}"
          execute_structured_command(command)
        else
          raise Hip::Error, "Invalid command format: #{command.inspect}. Expected String or Hash."
        end
      end

      def execute_structured_command(cmd_hash)
        key, value = cmd_hash.first

        case key.to_s
        when "echo"
          execute_echo(value)
        when "cmd"
          execute_cmd(value)
        when "shell"
          execute_shell(value)
        when "sleep"
          execute_sleep(value)
        when "docker"
          execute_docker(value)
        else
          raise Hip::Error, "Unknown provision command type: #{key}"
        end
      end

      def execute_echo(text)
        # Escape special characters in text
        escaped_text = Shellwords.escape(text.to_s)
        cmdline = "echo #{escaped_text}"
        Hip.logger.debug "Executing echo: #{cmdline}"
        exec_subprocess(cmdline)
      end

      def execute_cmd(cmd)
        raise Hip::Error, "cmd value must be a string" unless cmd.is_a?(String)

        Hip.logger.debug "Executing cmd: #{cmd}"
        exec_subprocess(cmd)
      end

      def execute_shell(script)
        raise Hip::Error, "shell value must be a string" unless script.is_a?(String)

        Hip.logger.debug "Executing shell script"
        exec_subprocess(script)
      end

      def execute_sleep(seconds)
        # Convert to integer or float
        sleep_duration = if seconds.is_a?(String)
          Float(seconds)
        else
          seconds
        end

        Hip.logger.debug "Sleeping for #{sleep_duration} seconds"
        ::Kernel.sleep(sleep_duration)
      end

      def execute_docker(docker_config)
        raise Hip::Error, "docker value must be an object/hash" unless docker_config.is_a?(Hash)

        if docker_config.key?(:compose) || docker_config.key?("compose")
          execute_docker_compose(docker_config[:compose] || docker_config["compose"])
        else
          raise Hip::Error, "docker command must have 'compose' key"
        end
      end

      def execute_docker_compose(compose_cmd)
        if compose_cmd.is_a?(Array)
          # Array of arguments: join with spaces
          cmdline = "docker compose #{compose_cmd.join(" ")}"
        elsif compose_cmd.is_a?(String)
          # String: use as-is
          cmdline = "docker compose #{compose_cmd}"
        else
          raise Hip::Error, "docker.compose must be a string or array"
        end

        Hip.logger.debug "Executing docker compose: #{cmdline}"
        exec_subprocess(cmdline)
      end

      def auto_generate_claude_files
        return unless Hip.config.exist?

        claude_guide = ".claude/ctx/hip-project-guide.md"

        # Only generate if .claude directory doesn't exist or guide is missing
        return if File.exist?(claude_guide)

        Hip.logger.debug "Auto-generating Claude Code integration files..."
        require_relative "claude/setup"
        Hip::Commands::Claude::Setup.new({}).execute
      rescue => e
        # Don't fail provision if Claude file generation fails
        Hip.logger.debug "Failed to auto-generate Claude files: #{e.message}"
      end
    end
  end
end
