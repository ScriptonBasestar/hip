# frozen_string_literal: true

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
      def initialize(cmd, *argv, **options)
        @options = options

        @command, @argv = InteractionTree
          .new(Hip.config.interaction)
          .find(cmd, *argv)&.values_at(:command, :argv)

        raise Hip::Error, "Command `#{[cmd, *argv].join(" ")}` not recognized!" unless command

        Hip.env.merge(command[:environment])
      end

      def execute
        lookup_runner
          .new(command, argv, **options)
          .execute
      end

      private

      attr_reader :command, :argv, :options

      def lookup_runner
        Hip.logger.debug "Dip.Commands.Run#lookup_runner command: #{command}"
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
    end
  end
end
