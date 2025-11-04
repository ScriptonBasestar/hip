# frozen_string_literal: true

require_relative "../../command"
require_relative "../../devcontainer"

module Hip
  module Commands
    module DevContainer
      class Validate < Hip::Command
        def execute
          devcontainer = Hip::DevContainer.new

          if devcontainer.validate
            config = devcontainer.read
            puts "✓ DevContainer configuration is valid"
            puts "\nConfiguration summary:"
            puts "  Name: #{config['name'] || '(not set)'}"
            puts "  Service: #{config['service'] || '(not set)'}"
            puts "  Image: #{config['image'] || '(using docker-compose)'}"
            puts "  Workspace: #{config['workspaceFolder'] || '/workspace'}"

            if config['features']
              puts "\n  Features (#{config['features'].keys.size}):"
              config['features'].keys.each do |feature|
                puts "    - #{feature}"
              end
            end

            if config['forwardPorts']
              puts "\n  Forward Ports: #{config['forwardPorts'].join(', ')}"
            end
          end
        rescue Hip::Error => e
          puts "✗ Validation failed: #{e.message}"
          exit 1
        end
      end
    end
  end
end
