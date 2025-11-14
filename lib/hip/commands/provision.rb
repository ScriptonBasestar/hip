# frozen_string_literal: true

require_relative "../command"

module Hip
  module Commands
    class Provision < Hip::Command
      def initialize(argv = [])
        @argv = argv
      end

      def execute
        Hip.logger.debug "Hip.Commands.Provision#execute >>>>>>>"
        provision_key = @argv.first || :default
        Hip.logger.debug "Hip.Commands.Provision #{Hip.config.provision}"

        # If provision is empty or key not found, just return without error
        return if Hip.config.provision.empty?

        commands = Hip.config.provision[provision_key.to_sym]

        if commands.nil?
          raise Hip::Error, "Provision key '#{provision_key}' not found!"
        end

        commands.each do |command|
          exec_subprocess(command)
        end

        # Auto-generate Claude Code integration files after successful provision
        auto_generate_claude_files
      end

      private

      def auto_generate_claude_files
        return unless Hip.config.exist?

        claude_guide = ".claude/ctx/hip-project-guide.md"

        # Only generate if .claude directory doesn't exist or guide is missing
        return if File.exist?(claude_guide)

        Hip.logger.debug "Auto-generating Claude Code integration files..."
        require_relative "claude/setup"
        Hip::Commands::Claude::Setup.new({}).execute
      rescue => e
        # Don't fail provision if Claude file generation fails
        Hip.logger.debug "Failed to auto-generate Claude files: #{e.message}"
      end
    end
  end
end
