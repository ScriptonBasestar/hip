# frozen_string_literal: true

# @file: lib/hip/command.rb
# @purpose: Base class for executable commands with program/subprocess runners
# @flow: Command classes inherit -> exec_program/exec_subprocess -> Kernel.exec/system
# @dependencies: forwardable, Hip::Environment (for interpolation)
# @key_methods: exec_program (replace process), exec_subprocess (spawn child)

require "forwardable"

module Hip
  class Command
    extend Forwardable

    def_delegators self, :exec_program, :exec_subprocess

    class ProgramRunner
      def self.call(cmdline, env: {}, **options)
        DebugLogger.method_entry("Command.ProgramRunner#call",
          cmdline: cmdline, env: env, options: options)
        DebugLogger.log_execution(cmdline, via: "exec")

        if cmdline.is_a?(Array)
          ::Kernel.exec(env, cmdline[0], *cmdline.drop(1), **options)
        else
          ::Kernel.exec(env, cmdline, **options)
        end
      end
    end

    class SubprocessRunner
      def self.call(cmdline, env: {}, panic: true, **options)
        DebugLogger.method_entry("Command.SubprocessRunner#call",
          cmdline: cmdline, panic: panic)
        status = ::Kernel.system(env, cmdline, **options)

        if !status && panic
          raise Hip::Error, "Command '#{cmdline}' executed with error"
        else
          status
        end
      end
    end

    class << self
      def exec_program(*args, **kwargs)
        run(ProgramRunner, *args, **kwargs)
      end

      def exec_subprocess(*args, **kwargs)
        run(SubprocessRunner, *args, **kwargs)
      end

      private

      def run(runner, cmd, argv = [], shell: true, **options)
        DebugLogger.method_entry("Command#run", cmd: cmd, argv: argv, shell: shell)

        cmd = Hip.env.interpolate(cmd)
        argv = [argv] if argv.is_a?(String)
        argv = argv.map { |arg| Hip.env.interpolate(arg) }
        cmdline = [cmd, *argv].compact
        cmdline = cmdline.join(" ").strip if shell

        DebugLogger.log_context("Command#run", cmdline: cmdline, env_vars: Hip.env.vars)

        runner.call(cmdline, env: Hip.env.vars, **options)
      end
    end
  end
end
