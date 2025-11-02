# frozen_string_literal: true

require_relative "../command"

module Dip
  module Commands
    class Provision < Dip::Command
      def initialize(argv = [])
        @argv = argv
      end

      def execute
        Dip.logger.debug "Dip.Commands.Provision#execute >>>>>>>"
        provision_key = @argv.first || :default
        Dip.logger.debug "Dip.Commands.Provision #{Dip.config.provision}"

        # If provision is empty or key not found, just return without error
        return if Dip.config.provision.empty?

        commands = Dip.config.provision[provision_key.to_sym]

        if commands.nil?
          raise Dip::Error, "Provision key '#{provision_key}' not found!"
        end

        commands.each do |command|
          exec_subprocess(command)
        end
      end
    end
  end
end
