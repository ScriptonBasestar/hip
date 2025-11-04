# frozen_string_literal: true

require_relative "../../command"
require_relative "../../devcontainer"

module Hip
  module Commands
    module DevContainer
      class Sync < Hip::Command
        VALID_DIRECTIONS = %w[to-dc from-dc both].freeze

        attr_reader :direction

        def initialize(direction: "both")
          @direction = direction
          validate_direction!
        end

        def execute
          devcontainer = Hip::DevContainer.new

          case direction
          when "to-dc"
            sync_to_devcontainer(devcontainer)
          when "from-dc"
            sync_from_devcontainer(devcontainer)
          when "both"
            sync_to_devcontainer(devcontainer)
            puts "\n"
            sync_from_devcontainer(devcontainer)
          end
        end

        private

        def validate_direction!
          return if VALID_DIRECTIONS.include?(direction)

          raise Hip::Error, "Invalid direction '#{direction}'. Must be one of: #{VALID_DIRECTIONS.join(", ")}"
        end

        def sync_to_devcontainer(devcontainer)
          puts "Syncing hip.yml → devcontainer.json..."
          devcontainer.sync_to_devcontainer
          puts "✓ Synced to #{devcontainer.devcontainer_path}"
        end

        def sync_from_devcontainer(devcontainer)
          puts "Reading devcontainer.json configuration..."

          hip_config = devcontainer.sync_from_devcontainer

          puts "✓ DevContainer configuration:"
          puts JSON.pretty_generate(hip_config)
          puts "\nTo apply this to hip.yml, add the following to your hip.yml:"
          puts "\ndevcontainer:"
          puts hip_config.to_yaml.lines.drop(1).join.gsub(/^/, "  ")
        end
      end
    end
  end
end
