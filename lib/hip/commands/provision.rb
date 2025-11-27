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

        commands.each do |command|
          execute_command(command)
        end

        # Auto-generate Claude Code integration files after successful provision
        auto_generate_claude_files
      end

      private

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
