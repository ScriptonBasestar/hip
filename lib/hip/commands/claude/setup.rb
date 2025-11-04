# frozen_string_literal: true

require "fileutils"
require_relative "../../command"
require_relative "../../interaction_tree"

module Hip
  module Commands
    module Claude
      class Setup < Hip::Command
        CLAUDE_DIR = ".claude"
        CTX_DIR = "#{CLAUDE_DIR}/ctx"
        COMMANDS_DIR = "#{CLAUDE_DIR}/commands"
        PROJECT_GUIDE_FILE = "#{CTX_DIR}/hip-project-guide.md"
        SLASH_COMMAND_FILE = "#{COMMANDS_DIR}/hip.md"
        GLOBAL_GUIDE_FILE = File.expand_path("~/.claude/ctx/HIP_QUICK_REFERENCE.md")

        def initialize(options = {})
          @options = options
        end

        def execute
          ensure_hip_config!
          create_directories
          generate_project_guide
          generate_slash_command
          generate_global_guide if @options[:global]
          print_success_message
        end

        private

        def ensure_hip_config!
          return if Hip.config.exist?

          raise Hip::Error, "No hip.yml found. Run 'hip init' first or navigate to a project with hip.yml"
        end

        def create_directories
          FileUtils.mkdir_p(CTX_DIR)
          FileUtils.mkdir_p(COMMANDS_DIR)
        end

        def generate_project_guide
          content = build_project_guide_content
          File.write(PROJECT_GUIDE_FILE, content)
          log_file_created(PROJECT_GUIDE_FILE)
        end

        def generate_slash_command
          content = build_slash_command_content
          File.write(SLASH_COMMAND_FILE, content)
          log_file_created(SLASH_COMMAND_FILE)
        end

        def generate_global_guide
          FileUtils.mkdir_p(File.dirname(GLOBAL_GUIDE_FILE))
          content = build_global_guide_content
          File.write(GLOBAL_GUIDE_FILE, content)
          log_file_created(GLOBAL_GUIDE_FILE)
        end

        def log_file_created(path)
          puts "Created: #{path}" unless ENV["RSPEC_RUNNING"]
        end

        def build_project_guide_content
          commands = InteractionTree.new(Hip.config.interaction).list
          project_name = File.basename(Dir.pwd)

          sections = [
            "# Hip Commands: #{project_name}",
            format_commands_table(commands),
            format_services_section,
            format_environment_section
          ].compact

          sections.join("\n\n")
        end

        def build_slash_command_content
          <<~MARKDOWN
            # Hip Command Helper

            Show available Hip commands for this project.

            ## Usage

            `/hip [command]`

            ## Examples

            - `/hip` - Show all commands
            - `/hip console` - Show command details
          MARKDOWN
        end

        def build_global_guide_content
          <<~MARKDOWN
            # Hip Quick Reference

            CLI tool for Docker Compose and Kubernetes workflows.

            ## Commands

            hip <cmd>           # Execute interaction command
            hip compose <args>  # Docker Compose wrapper
            hip ktl <args>      # Kubectl wrapper
            hip provision       # Run provisioning
            hip ls              # List commands
            hip validate        # Validate hip.yml
            hip claude:setup    # Generate Claude integration

            ## Config Structure

            ```
            version: '8'
            environment: {KEY: value}
            interaction:
              cmd-name: {service: name, command: text, description: text}
            provision: [commands...]
            ```

            ## Features

            | Feature | Usage |
            |---------|-------|
            | Shortcuts | `hip console` → `docker compose run --rm rails bin/rails console` |
            | Modules | Split config into `.hip/*.yml` |
            | Overrides | `hip.override.yml` (git-ignored) |
            | Runners | Docker (`service:`), K8s (`pod:`), Local (neither) |

            ## Common Patterns

            ```
            interaction:
              # Rails
              console: {service: rails, command: "bin/rails console"}
              migrate: {service: rails, command: "bin/rails db:migrate"}

              # Node.js
              dev: {service: frontend, command: "npm run dev"}
              build: {service: frontend, command: "npm run build"}

              # Multi-service
              api: {service: api, command: "bin/console"}
              worker: {service: worker, command: "bundle exec sidekiq"}
            ```

            ## Advanced

            hip ssh {up|down}            # SSH agent container
            hip infra {up|down} <name>   # Shared infrastructure
            eval "$(hip console inject)" # Shell aliases

            ## Predefined Variables

            HIP_OS, HIP_WORK_DIR_REL_PATH, HIP_CURRENT_USER
          MARKDOWN
        end

        def format_commands_table(commands)
          return nil if commands.empty?

          header = "## Commands\n\n| Command | Description |\n|---------|-------------|"
          rows = commands.map do |name, command|
            desc = command[:description] || ""
            "| hip #{name} | #{desc} |"
          end

          ([header] + rows).join("\n")
        end

        def format_services_section
          compose_config = Hip.config.compose
          return nil unless compose_config

          services = compose_config["services"]
          return nil unless services&.any?

          header = "## Services\n\n"
          service_list = services.keys.map { |s| "- #{s}" }.join("\n")
          header + service_list
        rescue
          nil
        end

        def format_environment_section
          env_config = Hip.config.environment
          return nil if env_config.nil? || env_config.empty?

          header = "## Environment\n\n"
          env_list = env_config.map { |k, v| "- #{k}: `#{v}`" }.join("\n")
          header + env_list
        rescue
          nil
        end

        def print_success_message
          return if ENV["RSPEC_RUNNING"]

          puts
          puts "✓ Claude Code integration files created successfully!"
          puts
          puts "Claude Code can now:"
          puts "  - Read project commands from: #{PROJECT_GUIDE_FILE}"
          puts "  - Use /hip slash command for interactive help"
          puts
          puts "Next steps:"
          puts "  1. Open Claude Code in this project"
          puts "  2. Ask: 'What Hip commands are available?'"
          puts "  3. Or use: /hip to see available commands"
          puts
          puts "To update after changing hip.yml, run: hip claude:setup"
        end
      end
    end
  end
end
