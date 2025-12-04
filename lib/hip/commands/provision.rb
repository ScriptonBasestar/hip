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
        provision_key = @argv.first || :default
        DebugLogger.method_entry("Provision#execute",
          provision_key: provision_key,
          provision_config: Hip.config.provision)

        # If provision is empty or key not found, just return without error
        return if Hip.config.provision.empty?

        commands = Hip.config.provision[provision_key.to_sym]

        if commands.nil?
          raise Hip::Error, "Provision key '#{provision_key}' not found!"
        end

        # Auto-start containers if not running
        ensure_containers_running

        # Count steps for progress display
        @total_steps = count_steps(commands)
        @current_step = 0

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
        DebugLogger.log("Checking if containers are running...")

        if any_containers_running?
          DebugLogger.log("Containers already running, proceeding with provision")
        else
          DebugLogger.log("No containers running. Starting with 'hip up -d --wait'...")
          puts "⚙️  Starting containers before provisioning..."
          puts ""

          # Use Compose with subprocess: true to run as child process
          # This allows provision to continue after containers start
          require_relative "compose"
          Commands::Compose.new("up", "-d", "--wait", subprocess: true).execute

          puts ""
          DebugLogger.log("Containers started successfully")
        end
      end

      def any_containers_running?
        # Delegate to ContainerUtils for centralized container status checking
        ContainerUtils.any_containers_running?
      end

      def execute_command(command)
        case command
        when String
          DebugLogger.log("Executing raw command: #{command}")
          exec_subprocess(command)
        when Hash
          DebugLogger.log("Executing structured command: #{command}")
          execute_structured_command(command)
        else
          raise Hip::Error, "Invalid command format: #{command.inspect}. Expected String or Hash."
        end
      end

      def execute_structured_command(cmd_hash)
        # Check for step-based syntax first
        if cmd_hash.key?(:step) || cmd_hash.key?("step")
          execute_step(cmd_hash)
          return
        end

        # Legacy structured command format
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

      def count_steps(commands)
        commands.count do |cmd|
          cmd.is_a?(Hash) && (cmd.key?(:step) || cmd.key?("step"))
        end
      end

      def execute_step(step_config)
        step_name = step_config[:step] || step_config["step"]
        run_cmds = step_config[:run] || step_config["run"]
        note = step_config[:note] || step_config["note"]

        @current_step += 1

        # Print step header with progress
        puts ""
        if @total_steps > 0
          puts "📦 [#{@current_step}/#{@total_steps}] #{step_name}"
        else
          puts "📦 #{step_name}"
        end

        # Print note if present (before commands)
        note&.to_s&.each_line do |line|
          puts "   ℹ️  #{line.rstrip}"
        end

        # Execute commands if present
        return unless run_cmds

        commands = run_cmds.is_a?(Array) ? run_cmds : [run_cmds]
        commands.each do |cmd|
          puts "   → #{cmd}"
          exec_subprocess(cmd)
        end
      end

      def execute_echo(text)
        escaped_text = Shellwords.escape(text.to_s)
        cmdline = "echo #{escaped_text}"
        DebugLogger.log("Executing echo: #{cmdline}")
        exec_subprocess(cmdline)
      end

      def execute_cmd(cmd)
        raise Hip::Error, "cmd value must be a string" unless cmd.is_a?(String)

        DebugLogger.log("Executing cmd: #{cmd}")
        exec_subprocess(cmd)
      end

      def execute_shell(script)
        raise Hip::Error, "shell value must be a string" unless script.is_a?(String)

        DebugLogger.log("Executing shell script")
        exec_subprocess(script)
      end

      def execute_sleep(seconds)
        sleep_duration = if seconds.is_a?(String)
          Float(seconds)
        else
          seconds
        end

        DebugLogger.log("Sleeping for #{sleep_duration} seconds")
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
        # Convert to array of arguments
        args = if compose_cmd.is_a?(Array)
          compose_cmd
        elsif compose_cmd.is_a?(String)
          compose_cmd.split
        else
          raise Hip::Error, "docker.compose must be a string or array"
        end

        DebugLogger.log("Executing docker compose: #{args.join(" ")}")
        Commands::Compose.new(*args, subprocess: true).execute
      end

      def auto_generate_claude_files
        return unless Hip.config.exist?

        claude_guide = ".claude/ctx/hip-project-guide.md"
        return if File.exist?(claude_guide)

        DebugLogger.log("Auto-generating Claude Code integration files...")
        require_relative "claude/setup"
        Hip::Commands::Claude::Setup.new({}).execute
      rescue => e
        DebugLogger.log_error("auto_generate_claude_files", e)
      end
    end
  end
end
