# frozen_string_literal: true

require_relative "../command"

module Hip
  module Commands
    class Provision < Hip::Command
      def initialize(argv = [])
        @argv = argv
      end

      def execute
        Hip.logger.debug "Dip.Commands.Provision#execute >>>>>>>"
        provision_key = @argv.first || :default
        Hip.logger.debug "Dip.Commands.Provision #{Hip.config.provision}"

        # If provision is empty or key not found, just return without error
        return if Hip.config.provision.empty?

        commands = Hip.config.provision[provision_key.to_sym]

        if commands.nil?
          raise Hip::Error, "Provision key '#{provision_key}' not found!"
        end

        commands.each do |command|
          exec_subprocess(command)
        end
      end
    end
  end
end
