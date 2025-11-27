# frozen_string_literal: true

# @file: lib/hip/commands/runners/local_runner.rb
# @purpose: Execute commands directly on host machine (no containerization)
# @flow: Run -> LocalRunner.execute -> Hip::Command.exec_program
# @dependencies: Base, Hip::Command
# @key_methods: execute (simple pass-through to exec_program)

require_relative "base"
require_relative "../../command"

module Hip
  module Commands
    module Runners
      class LocalRunner < Base
        def execute
          Hip::Command.exec_program(
            command[:command],
            command_args,
            shell: command[:shell]
          )
        end
      end
    end
  end
end
