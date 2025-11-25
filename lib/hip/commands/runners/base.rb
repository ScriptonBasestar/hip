# frozen_string_literal: true
# @file: lib/hip/commands/runners/base.rb
# @purpose: Abstract base class for command execution strategies
# @flow: Run.lookup_runner -> Runner.new -> Runner.execute
# @dependencies: Hip::Command (for exec methods)
# @key_methods: initialize, execute, command_args

module Hip
  module Commands
    module Runners
      class Base
        def initialize(command, argv, **options)
          @command = command
          @argv = argv
          @options = options
        end

        def execute
          raise NotImplementedError
        end

        private

        attr_reader :command, :argv, :options

        def command_args
          if argv.any?
            if command[:shell]
              [argv.shelljoin]
            else
              Array(argv)
            end
          elsif !(default_args = command[:default_args]).empty?
            if command[:shell]
              default_args.shellsplit
            else
              Array(default_args)
            end
          else
            []
          end
        end
      end
    end
  end
end
