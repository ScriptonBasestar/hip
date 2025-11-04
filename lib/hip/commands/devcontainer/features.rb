# frozen_string_literal: true

require_relative "../../command"
require_relative "../../devcontainer"

module Hip
  module Commands
    module DevContainer
      class Features < Hip::Command
        attr_reader :list

        def initialize(list: false)
          @list = list
        end

        def execute
          if list
            list_feature_shortcuts
          else
            show_installed_features
          end
        end

        private

        def list_feature_shortcuts
          puts "Available feature shortcuts:\n\n"

          Hip::DevContainer::FEATURE_SHORTCUTS.each do |shortcut, full_name|
            puts "  #{shortcut.ljust(20)} → #{full_name}"
          end

          puts "\nUsage in hip.yml:"
          puts "  devcontainer:"
          puts "    features:"
          puts "      docker-in-docker: {}"
          puts "      github-cli:"
          puts "        version: latest"
        end

        def show_installed_features
          devcontainer = Hip::DevContainer.new

          unless File.exist?(devcontainer.devcontainer_path)
            puts "No devcontainer.json found"
            puts "Run 'hip devcontainer init' to create one"
            return
          end

          config = devcontainer.read
          features = config["features"]

          if features.nil? || features.empty?
            puts "No features installed"
            puts "\nTo add features, edit hip.yml:"
            puts "  devcontainer:"
            puts "    features:"
            puts "      docker-in-docker: {}"
            return
          end

          puts "Installed features:\n\n"
          features.each do |name, options|
            puts "  #{name}"
            unless options.empty?
              options.each do |key, value|
                puts "    #{key}: #{value}"
              end
            end
          end

          puts "\n#{features.size} feature(s) installed"
        end
      end
    end
  end
end
