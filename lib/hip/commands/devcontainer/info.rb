# frozen_string_literal: true

require_relative "../../command"
require_relative "../../devcontainer"

module Hip
  module Commands
    module DevContainer
      class Info < Hip::Command
        def execute
          devcontainer = Hip::DevContainer.new

          puts "DevContainer Integration Status\n\n"

          # Check if enabled in hip.yml
          if Hip.config.to_h.key?(:devcontainer)
            dc_config = Hip.config.devcontainer
            if dc_config.is_a?(Hash)
              puts "✓ DevContainer configuration found in hip.yml"
              puts "  Enabled: #{dc_config.fetch(:enabled, true)}"
              puts "  Service: #{dc_config[:service] || devcontainer.service_name}"
            else
              puts "✗ DevContainer section in hip.yml is not properly configured"
            end
          else
            puts "○ No devcontainer configuration in hip.yml"
          end

          puts ""

          # Check if devcontainer.json exists
          if File.exist?(devcontainer.devcontainer_path)
            puts "✓ DevContainer file exists: #{devcontainer.devcontainer_path}"

            begin
              config = devcontainer.read
              puts "\n  Configuration:"
              puts "    Name: #{config["name"] || "(not set)"}"
              puts "    Service: #{config["service"] || config["image"] || "(not set)"}"
              puts "    Workspace: #{config["workspaceFolder"] || "(not set)"}"
              puts "    Features: #{config["features"]&.keys&.size || 0}"
              puts "    Ports: #{config["forwardPorts"]&.size || 0}"
            rescue Hip::Error => e
              puts "  ✗ Error reading devcontainer.json: #{e.message}"
            end
          else
            puts "○ DevContainer file not found: #{devcontainer.devcontainer_path}"
            puts "\n  Run 'hip devcontainer init' to create one"
          end

          puts "\nAvailable commands:"
          puts "  hip devcontainer init       - Generate devcontainer.json"
          puts "  hip devcontainer sync       - Sync configurations"
          puts "  hip devcontainer validate   - Validate devcontainer.json"
          puts "  hip devcontainer shell      - Open shell in container"
          puts "  hip devcontainer provision  - Run postCreateCommand"
          puts "  hip devcontainer features   - Manage features"
        end
      end
    end
  end
end
