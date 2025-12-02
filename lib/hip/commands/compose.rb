# frozen_string_literal: true

require "pathname"

require_relative "../command"
require_relative "dns"

module Hip
  module Commands
    class Compose < Hip::Command
      DOCKER_EMBEDDED_DNS = "127.0.0.11"

      attr_reader :argv, :config, :shell, :subprocess

      # @param argv [Array] Command arguments
      # @param shell [Boolean] Use shell execution (default: true)
      # @param subprocess [Boolean] Run as subprocess instead of exec (default: false)
      #   - false: Uses exec_program (Kernel.exec) - replaces current process
      #   - true: Uses exec_subprocess (Kernel.system) - runs as child process and returns
      def initialize(*argv, shell: true, subprocess: false)
        @argv = argv.compact
        @shell = shell
        @subprocess = subprocess
        @config = ::Hip.config.compose || {}
      end

      def execute
        Hip.logger.debug "Hip.Commands.Compose#execute >>>>>>>"
        Hip.env["HIP_DNS"] ||= find_dns

        set_infra_env

        if (override_command = compose_command_override)
          override_command, *override_args = override_command.split(" ")
          run_command(override_command, override_args.concat(build_argv))
        else
          run_command("docker", build_argv.unshift("compose"))
        end
      end

      # Build the full command array for external use (e.g., capturing output)
      # @return [Array<String>] Full docker compose command with all options
      def build_command
        ["docker", "compose"] + Array(find_files) + Array(cli_options) + argv
      end

      # Build argv with files and options
      def build_argv
        Array(find_files) + Array(cli_options) + argv
      end

      private

      def run_command(cmd, args)
        if subprocess
          exec_subprocess(cmd, args, shell: shell)
        else
          exec_program(cmd, args, shell: shell)
        end
      end

      def find_files
        return unless (files = config[:files])

        if files.is_a?(Array)
          files.each_with_object([]) do |file_path, memo|
            file_path = ::Hip.env.interpolate(file_path)
            file_path = Pathname.new(file_path)
            file_path = Hip.config.file_path.parent.join(file_path).expand_path if file_path.relative?
            next unless file_path.exist?

            memo << "--file"
            memo << Shellwords.escape(file_path.to_s)
          end
        end
      end

      def cli_options
        %i[project_name project_directory].flat_map do |name|
          next unless (value = config[name])
          next unless value.is_a?(String)

          value = ::Hip.env.interpolate(value)
          ["--#{name.to_s.tr("_", "-")}", value]
        end.compact
      end

      def find_dns
        name = Hip.env["DNSDOCK_CONTAINER"] || "dnsdock"
        net = Hip.env["FRONTEND_NETWORK"] || "frontend"

        IO.pipe do |r, w|
          Hip::Commands::DNS::IP
            .new(name: name, net: net)
            .execute(out: w, err: File::NULL, panic: false)

          w.close_write
          ip = r.readlines[0].to_s.strip
          ip.empty? ? DOCKER_EMBEDDED_DNS : ip
        end
      end

      def compose_command_override
        Hip.env["HIP_COMPOSE_COMMAND"] || config[:command]
      end

      def set_infra_env
        Hip.config.infra.each do |name, params|
          service = Commands::Infra::Service.new(name, **params)
          Hip.env[service.network_env_var] = service.network_name
        end
      end
    end
  end
end
