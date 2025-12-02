# frozen_string_literal: true

require_relative "../../command"
require_relative "../../devcontainer"
require_relative "../compose"

module Hip
  module Commands
    module DevContainer
      class Provision < Hip::Command
        def execute
          devcontainer = Hip::DevContainer.new

          # Check if devcontainer.json exists
          unless File.exist?(devcontainer.devcontainer_path)
            raise Hip::Error, "DevContainer file not found: #{devcontainer.devcontainer_path}"
          end

          config = devcontainer.read
          post_create_command = config["postCreateCommand"]

          unless post_create_command
            puts "No postCreateCommand defined in devcontainer.json"
            return
          end

          puts "Running postCreateCommand..."
          run_command(post_create_command, devcontainer.service_name)
          puts "✓ Provision complete"
        end

        private

        def run_command(command, service)
          commands = command.is_a?(Array) ? command : [command]

          commands.each do |cmd|
            puts "  → #{cmd}"
            # Use Compose with subprocess: true to run as child process
            Commands::Compose.new(
              "exec", "-T", service, "sh", "-c", cmd,
              subprocess: true
            ).execute
          end
        end
      end
    end
  end
end
