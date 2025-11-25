# frozen_string_literal: true
# @file: lib/hip/command_registry.rb
# @purpose: Centralized command metadata for AI discoverability
# @flow: CLI.manifest -> CommandRegistry.manifest -> JSON/YAML output
# @dependencies: Hip::InteractionTree, Hip::VERSION, json, yaml
# @key_methods: manifest (generates complete command metadata)

require "json"
require "yaml"
require_relative "interaction_tree"
require_relative "version"

module Hip
  class CommandRegistry
    STATIC_COMMANDS = {
      version: {
        description: "Show Hip version",
        type: :builtin,
        aliases: %w[--version -v]
      },
      ls: {
        description: "List available run commands",
        type: :builtin,
        options: {
          format: "Output format (table, json, yaml)",
          detailed: "Show detailed information"
        }
      },
      compose: {
        description: "Run Docker Compose commands",
        type: :compose,
        accepts_args: true
      },
      build: {
        description: "Run docker compose build",
        type: :compose_shortcut
      },
      up: {
        description: "Run docker compose up",
        type: :compose_shortcut
      },
      stop: {
        description: "Run docker compose stop",
        type: :compose_shortcut
      },
      down: {
        description: "Run docker compose down",
        type: :compose_shortcut,
        options: {
          all: "Shutdown all Docker Compose projects"
        }
      },
      ktl: {
        description: "Run kubectl commands",
        type: :kubectl,
        accepts_args: true
      },
      run: {
        description: "Run configured command (run prefix may be omitted)",
        type: :dynamic_router,
        options: {
          publish: "Publish container ports to host",
          explain: "Show execution plan without running"
        }
      },
      provision: {
        description: "Execute provision scripts",
        type: :provision
      },
      validate: {
        description: "Validate hip.yml against schema",
        type: :builtin
      },
      manifest: {
        description: "Output complete command manifest",
        type: :builtin,
        options: {
          format: "Output format (json, yaml)"
        }
      }
    }.freeze

    SUBCOMMAND_GROUPS = {
      ssh: {
        description: "SSH agent container commands",
        commands: {
          up: {description: "Run ssh-agent container"},
          down: {description: "Stop ssh-agent container"},
          restart: {description: "Restart ssh-agent container"},
          status: {description: "Show ssh-agent status"}
        }
      },
      infra: {
        description: "Infrastructure services",
        commands: {
          update: {description: "Pull infra service updates"},
          up: {description: "Run infra services"},
          down: {description: "Stop infra services"}
        }
      },
      console: {
        description: "Shell integration (ZSH and Bash)",
        commands: {
          start: {description: "Integrate Hip into shell"},
          inject: {description: "Inject aliases"}
        }
      },
      devcontainer: {
        description: "VSCode DevContainer integration",
        commands: {
          init: {description: "Generate devcontainer.json"},
          sync: {description: "Sync with hip.yml"},
          validate: {description: "Validate devcontainer.json"},
          bash: {description: "Open shell in devcontainer"},
          provision: {description: "Run postCreateCommand"},
          features: {description: "Manage devcontainer features"},
          info: {description: "Show devcontainer info"}
        }
      },
      claude: {
        description: "Claude Code integration",
        commands: {
          setup: {description: "Generate Claude integration files"}
        }
      }
    }.freeze

    RUNNERS = {
      docker_compose: {
        trigger: "service key present in command config",
        file: "lib/hip/commands/runners/docker_compose_runner.rb",
        description: "Executes commands in Docker Compose services"
      },
      kubectl: {
        trigger: "pod key present in command config",
        file: "lib/hip/commands/runners/kubectl_runner.rb",
        description: "Executes commands in Kubernetes pods"
      },
      local: {
        trigger: "neither service nor pod specified",
        file: "lib/hip/commands/runners/local_runner.rb",
        description: "Executes commands on local host"
      }
    }.freeze

    class << self
      def manifest
        {
          hip_version: Hip::VERSION,
          schema_version: "1.0",
          generated_at: Time.now.iso8601,
          config_file: Hip.config.file_path.to_s,
          static_commands: STATIC_COMMANDS,
          subcommand_groups: SUBCOMMAND_GROUPS,
          dynamic_commands: dynamic_commands,
          runners: RUNNERS
        }
      end

      def to_json
        JSON.pretty_generate(manifest)
      end

      def to_yaml
        YAML.dump(manifest)
      end

      private

      def dynamic_commands
        return {} unless Hip.config.exist?

        tree = InteractionTree.new(Hip.config.interaction).list
        tree.transform_values do |command|
          {
            description: command[:description],
            command: command[:command],
            runner: determine_runner(command),
            service: command[:service],
            pod: command[:pod],
            shell: command[:shell],
            environment: command[:environment]&.any? ? command[:environment] : nil
          }.compact
        end
      rescue StandardError => e
        {error: "Failed to load dynamic commands: #{e.message}"}
      end

      def determine_runner(command)
        if command[:runner]
          command[:runner]
        elsif command[:service]
          "docker_compose"
        elsif command[:pod]
          "kubectl"
        else
          "local"
        end
      end
    end
  end
end
