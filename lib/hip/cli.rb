# frozen_string_literal: true

# @file: lib/hip/cli.rb
# @purpose: Thor-based CLI interface, routes commands to implementations
# @flow: exe/hip -> CLI.start(ARGV) -> RunVars -> Thor routing -> Command classes
# @dependencies: thor, hip/run_vars, command classes (lazy loaded)
# @key_methods: start (dynamic routing), run, compose, provision, ls

require "thor"
require "hip/run_vars"

module Hip
  class CLI < Thor
    TOP_LEVEL_COMMANDS = %w[help version ls compose up stop down clean run provision ssh infra console validate manifest devcontainer claude migrate]

    class << self
      # Hackery. Take the run method away from Thor so that we can redefine it.
      def is_thor_reserved_word?(word, type)
        return false if word == "run"

        super
      end

      def exit_on_failure?
        true
      end

      def start(argv)
        # Handle --debug flag early, before any other processing
        if argv.include?("--debug")
          ENV["HIP_DEBUG"] = "1"
          argv.delete("--debug")
          Hip.logger.level = Logger::DEBUG
        end

        Hip.logger.debug "Hip.CLI#start >>>>>>>>>>"
        argv = Hip::RunVars.call(argv, ENV)

        cmd = argv.first
        Hip.logger.debug "Hip.CLI#start cmd: #{cmd}"

        # If no command provided, show helpful message
        if argv.empty?
          show_quick_help
          return
        end

        # Handle dynamic command routing: if first arg is not a top-level command
        # but matches an interaction command, prepend 'run' and move options
        if cmd && !TOP_LEVEL_COMMANDS.include?(cmd) && Hip.config.exist? && Hip.config.interaction.key?(cmd.to_sym)
          # Extract options (arguments starting with -)
          options = argv.select { |arg| arg.start_with?("-") }
          non_options = argv.reject { |arg| arg.start_with?("-") }

          # Reconstruct as: run [options] cmd [args]
          argv = ["run"] + options + non_options
        end

        super(Hip::RunVars.call(argv, ENV))
      rescue Hip::Error => e
        warn "\nERROR: #{e.message}\n"
        exit 1
      end

      def show_quick_help
        puts <<~HELP
          Hip - Docker Compose/Kubernetes CLI wrapper

          Usage: hip [--debug] COMMAND [ARGS]

          Available Commands:
            hip ls                List available interaction commands
            hip run CMD [ARGS]    Run interaction command from hip.yml
            hip provision         Run initialization scripts (after 'hip up')

          Docker Compose:
            hip compose ARGS      Run docker compose commands
            hip up [SERVICE]      Start services (docker compose up)
            hip down              Stop and remove containers
            hip clean             Remove all containers/networks (resolves conflicts)
            hip stop [SERVICE]    Stop services
            hip build [SERVICE]   Build service images

          Kubernetes:
            hip ktl CMD [OPTIONS] Run kubectl commands

          Configuration:
            hip validate          Validate hip.yml schema
            hip migrate           Generate migration guide for hip.yml upgrade
            hip manifest          Output complete command manifest

          Integration:
            hip ssh               SSH-agent container commands
            hip infra             Infrastructure services
            hip console           Shell integration (ZSH/Bash)
            hip devcontainer      VSCode DevContainer integration
            hip claude            Claude Code integration

          Options:
            --debug               Enable debug logging
            --version, -v         Show version

          For detailed help: hip help [COMMAND]
        HELP
      end
    end

    stop_on_unknown_option! :run, :ktl

    desc "version", "dip version"
    def version
      require_relative "version"
      puts Hip::VERSION
    end
    map %w[--version -v] => :version

    desc "ls [OPTIONS]", "List available run commands"
    method_option :format, aliases: "-f", type: :string, default: "table",
      desc: "Output format (table, json, yaml)"
    method_option :detailed, aliases: "-d", type: :boolean, default: false,
      desc: "Show detailed information (runner, service, command)"
    def ls
      require_relative "commands/list"
      Hip::Commands::List.new(
        format: options[:format],
        detailed: options[:detailed]
      ).execute
    end

    desc "compose CMD [OPTIONS]", "Run Docker Compose commands"
    def compose(*argv)
      require_relative "commands/compose"
      Hip::Commands::Compose.new(*argv).execute
    end

    desc "build [OPTIONS] SERVICE", "Run `docker compose build` command"
    def build(*argv)
      compose("build", *argv)
    end

    desc "up [OPTIONS] SERVICE", "Run `docker compose up` command (default: -d --wait)"
    method_option :foreground, aliases: "-f", type: :boolean, default: false,
      desc: "Run in foreground (disable default -d --wait)"
    def up(*argv)
      # Apply default options unless --foreground is specified
      unless options[:foreground]
        # Get custom up_options from config, or use default [-d, --wait]
        default_options = Hip.config.exist? && Hip.config.compose[:up_options] || ["-d", "--wait"]

        # Only add default options if not already present
        default_options.reverse_each do |opt|
          argv.unshift(opt) unless argv.include?(opt)
        end
      end

      compose("up", *argv)
    end

    desc "stop [OPTIONS] SERVICE", "Run `docker compose stop` command"
    def stop(*argv)
      compose("stop", *argv)
    end

    desc "down [OPTIONS]", "Run `docker compose down` command"
    method_option :help, aliases: "-h", type: :boolean, desc: "Display usage information"
    method_option :all, aliases: "-A", type: :boolean, desc: "Shutdown all running Docker Compose projects"
    def down(*argv)
      if options[:help]
        invoke :help, ["down"]
      elsif options[:all]
        require_relative "commands/down_all"
        Hip::Commands::DownAll.new.execute
      else
        compose("down", *argv.push("--remove-orphans"))
      end
    end

    desc "clean [OPTIONS]", "Remove all containers, networks, and optionally volumes"
    method_option :volumes, aliases: "-v", type: :boolean, default: false,
      desc: "Also remove volumes (WARNING: data loss)"
    method_option :images, aliases: "-i", type: :boolean, default: false,
      desc: "Also remove images built by docker compose"
    method_option :force, aliases: "-f", type: :boolean, default: false,
      desc: "Skip confirmation prompt"
    def clean
      require_relative "commands/clean"
      Hip::Commands::Clean.new(
        volumes: options[:volumes],
        images: options[:images],
        force: options[:force]
      ).execute
    end

    desc "ktl CMD [OPTIONS]", "Run kubectl commands"
    def ktl(*argv)
      require_relative "commands/kubectl"
      Hip::Commands::Kubectl.new(*argv).execute
    end

    desc "run [OPTIONS] CMD [ARGS]", "Run configured command (`run` prefix may be omitted)"
    method_option :publish, aliases: "-p", type: :string, repeatable: true,
      desc: "Publish a container's port(s) to the host"
    method_option :explain, aliases: "-e", type: :boolean,
      desc: "Show execution plan without running"
    method_option :help, aliases: "-h", type: :boolean, desc: "Display usage information"
    def run(*argv)
      if argv.empty? || options[:help]
        invoke :help, ["run"]
      else
        require_relative "commands/run"

        opts = options.to_h.transform_keys(&:to_sym)
        explain = opts.delete(:explain)

        Hip::Commands::Run.new(
          *argv,
          explain: explain || false,
          **opts
        ).execute
      end
    end

    desc "provision", "Execute commands within provision section"
    method_option :help, aliases: "-h", type: :boolean,
      desc: "Display usage information"
    def provision(*argv)
      Hip.logger.debug "Hip.CLI#provision >>>>>>>>>>"
      Hip.logger.debug "Hip.CLI#provision argv: #{argv}"
      if options[:help]
        invoke :help, ["provision"]
      # elsif argv.empty?
      #   require_relative "commands/provision"
      #   Hip::Commands::Provision.new.execute
      else
        require_relative "commands/provision"
        Hip::Commands::Provision.new(argv).execute
      end
    end

    desc "validate", "Validate the hip.yml file against the schema"
    method_option :verbose, aliases: "-v", type: :boolean, default: false,
      desc: "Show detailed validation output including container_name warnings"
    def validate
      Hip.config.validate
      puts "hip.yml is valid"

      # Check for container_name usage and report
      detection = ContainerUtils.detect_container_name_usage
      if detection && detection[:services].any?
        puts ""
        if options[:verbose]
          warn ContainerUtils.send(:format_container_name_warning, detection)
        else
          warn "WARNING: container_name detected in compose files"
          warn "  Services: #{detection[:services].keys.join(", ")}"
          if detection[:project_name]
            warn "  project_name: \"#{detection[:project_name]}\" (potential conflict)"
          end
          warn "  Run 'hip validate --verbose' for details"
        end
      end
    rescue Hip::Error => e
      warn "Validation failed: #{e.message}"
      exit 1
    end

    desc "migrate [OPTIONS]", "Generate migration guide for hip.yml version upgrade"
    method_option :to, type: :string, desc: "Target version (default: latest)"
    method_option :summary, type: :boolean, default: false, desc: "Show summary only"
    method_option :help, aliases: "-h", type: :boolean, desc: "Display usage information"
    def migrate
      if options[:help]
        invoke :help, ["migrate"]
      else
        require_relative "commands/migrate"
        Hip::Commands::Migrate.new(
          to: options[:to],
          summary: options[:summary]
        ).execute
      end
    end

    desc "manifest [OPTIONS]", "Output complete command manifest"
    method_option :format, aliases: "-f", type: :string, default: "json",
      desc: "Output format (json, yaml)"
    def manifest
      require_relative "command_registry"

      output = case options[:format]
      when "yaml"
        Hip::CommandRegistry.to_yaml
      else
        Hip::CommandRegistry.to_json
      end

      puts output
    end

    require_relative "cli/ssh"
    desc "ssh", "ssh-agent container commands"
    subcommand :ssh, Hip::CLI::SSH

    require_relative "cli/infra"
    desc "infra", "Infrastructure services"
    subcommand :infra, Hip::CLI::Infra

    require_relative "cli/console"
    desc "console", "Integrate Hip commands into shell (only ZSH and Bash are supported)"
    subcommand :console, Hip::CLI::Console

    require_relative "cli/devcontainer"
    desc "devcontainer", "DevContainer integration commands"
    subcommand :devcontainer, Hip::CLI::DevContainer

    require_relative "cli/claude"
    desc "claude", "Claude Code integration commands"
    subcommand :claude, Hip::CLI::Claude
  end
end
