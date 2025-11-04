# frozen_string_literal: true

require_relative "base"

module Hip
  class CLI
    class DevContainer < Base
      desc "init [OPTIONS]", "Generate .devcontainer/devcontainer.json from hip.yml"
      method_option :template, aliases: "-t", type: :string,
        desc: "Use a template (ruby, node, python, go, full-stack)"
      method_option :force, aliases: "-f", type: :boolean, default: false,
        desc: "Overwrite existing devcontainer.json"
      def init
        require_relative "../commands/devcontainer/init"
        Hip::Commands::DevContainer::Init.new(
          template: options[:template],
          force: options[:force]
        ).execute
      end

      desc "sync [OPTIONS]", "Sync configuration between hip.yml and devcontainer.json"
      method_option :direction, aliases: "-d", type: :string, default: "both",
        desc: "Sync direction: to-dc, from-dc, or both"
      def sync
        require_relative "../commands/devcontainer/sync"
        Hip::Commands::DevContainer::Sync.new(
          direction: options[:direction]
        ).execute
      end

      desc "validate", "Validate devcontainer.json configuration"
      def validate
        require_relative "../commands/devcontainer/validate"
        Hip::Commands::DevContainer::Validate.new.execute
      end

      desc "bash", "Open shell in devcontainer service"
      method_option :user, aliases: "-u", type: :string,
        desc: "User to run as"
      def bash
        require_relative "../commands/devcontainer/shell"
        Hip::Commands::DevContainer::Shell.new(
          user: options[:user]
        ).execute
      end

      desc "provision", "Run devcontainer postCreateCommand"
      def provision
        require_relative "../commands/devcontainer/provision"
        Hip::Commands::DevContainer::Provision.new.execute
      end

      desc "features", "Manage devcontainer features"
      method_option :list, aliases: "-l", type: :boolean, default: false,
        desc: "List available feature shortcuts"
      def features
        require_relative "../commands/devcontainer/features"
        Hip::Commands::DevContainer::Features.new(
          list: options[:list]
        ).execute
      end

      desc "info", "Show devcontainer configuration info"
      def info
        require_relative "../commands/devcontainer/info"
        Hip::Commands::DevContainer::Info.new.execute
      end

      default_task :info
    end
  end
end
