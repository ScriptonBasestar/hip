# frozen_string_literal: true

require "thor"

module Hip
  class CLI < Thor
    class Claude < Thor
      desc "setup", "Generate Claude Code integration files for this project"
      method_option :global, type: :boolean, default: false,
        desc: "Also create global reference guide at ~/.claude/ctx/"
      def setup
        require_relative "../commands/claude/setup"
        Hip::Commands::Claude::Setup.new(options).execute
      end
    end
  end
end
