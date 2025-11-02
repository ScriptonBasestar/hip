# frozen_string_literal: true

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
