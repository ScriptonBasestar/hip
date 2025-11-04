# frozen_string_literal: true

require_relative "../../command"
require_relative "../../devcontainer"

module Hip
  module Commands
    module DevContainer
      class Shell < Hip::Command
        attr_reader :user

        def initialize(user: nil)
          @user = user
        end

        def execute
          devcontainer = Hip::DevContainer.new
          service = devcontainer.service_name

          # Build docker-compose exec command
          cmd = ["docker", "compose", "exec"]
          cmd += ["-u", user] if user
          cmd += [service, "/bin/bash"]

          puts "Opening shell in devcontainer service '#{service}'..."
          exec_program(cmd.first, cmd.drop(1), shell: false)
        end
      end
    end
  end
end
