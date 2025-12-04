# frozen_string_literal: true

# @file: lib/hip/commands/run.rb
# @purpose: Execute interaction commands from hip.yml, dispatch to runners
# @flow: CLI.run -> Run.new -> InteractionTree.find -> lookup_runner -> Runner.execute
# @dependencies: InteractionTree, Runners (DockerCompose/Kubectl/Local)
# @key_methods: initialize, execute, lookup_runner

require "shellwords"
require_relative "../../../lib/hip/run_vars"
require_relative "../command"
require_relative "../interaction_tree"
require_relative "runners/local_runner"
require_relative "runners/docker_compose_runner"
require_relative "runners/kubectl_runner"

require_relative "kubectl"

module Hip
  module Commands
    class Run < Hip::Command
      def initialize(cmd, *argv, explain: false, **options)
        @options = options
        @explain_mode = explain

        @command, @argv = InteractionTree
          .new(Hip.config.interaction)
          .find(cmd, *argv)&.values_at(:command, :argv)

        raise Hip::Error, "Command `#{[cmd, *argv].join(" ")}` not recognized!" unless command

        # Load interaction-level env_file if present
        if command[:env_file]
          load_interaction_env_file
        end

        # Merge interaction-level environment variables
        Hip.env.merge(command[:environment])
      end

      def execute
        if @explain_mode
          explain_execution
        else
          lookup_runner
            .new(command, argv, **options)
            .execute
        end
      end

      private

      attr_reader :command, :argv, :options

      def explain_execution
        runner_class = lookup_runner
        puts "=== Command Execution Plan ==="
        puts "Command: #{command[:command]}"
        puts "Description: #{command[:description]}" if command[:description]
        puts "Runner: #{runner_class.name.split("::").last}"
        puts "Service: #{command[:service]}" if command[:service]
        puts "Pod: #{command[:pod]}" if command[:pod]
        puts "Compose Method: #{command.dig(:compose, :method)}" if command[:service]
        puts "Arguments: #{argv.join(" ")}" if argv.any?
        puts "Shell Mode: #{command[:shell]}"
        puts "Environment Variables:" if command[:environment]&.any?
        command[:environment]&.each do |key, value|
          puts "  #{key}=#{value}"
        end
      end

      def lookup_runner
        DebugLogger.method_entry("Run#lookup_runner", command: command)
        if (runner = command[:runner])
          camelized_runner = runner.split("_").collect(&:capitalize).join
          Runners.const_get("#{camelized_runner}Runner")
        elsif command[:service]
          Runners::DockerComposeRunner
        elsif command[:pod]
          Runners::KubectlRunner
        else
          Runners::LocalRunner
        end
      end

      def load_interaction_env_file
        require "hip/env_file_loader"

        DebugLogger.log("Loading interaction-level env_file: #{command[:env_file].inspect}")

        env_file_vars = Hip::EnvFileLoader.load(
          command[:env_file],
          base_path: Hip.config.file_path.parent,
          interpolate: true
        )

        Hip.env.merge(env_file_vars)

        DebugLogger.log("Loaded #{env_file_vars.size} variables from interaction env_file")
      rescue Hip::Error => e
        raise e
      rescue => e
        raise Hip::Error, "Failed to load interaction env_file: #{e.message}"
      end
    end
  end
end
