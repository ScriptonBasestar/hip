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
        Hip.logger.debug "Hip.Command.ProgramRunner#self.call >>>>>>>>>>"
        Hip.logger.debug "Hip.Command.ProgramRunner#self.call cmdline: #{cmdline}"
        Hip.logger.debug "Hip.Command.ProgramRunner#self.call env: #{env}"
        Hip.logger.debug "Hip.Command.ProgramRunner#self.call options: #{options}"

        # Show command in debug mode before exec replaces the process
        if Hip.debug?
          warn "\n" + "=" * 80
          warn "🔍 DEBUG: Executing command (via exec)"
          warn "=" * 80
          warn "Command: #{cmdline.is_a?(Array) ? cmdline.join(" ") : cmdline}"
          warn "=" * 80 + "\n"
        end

        if cmdline.is_a?(Array)
          Hip.logger.debug "Hip.Command.ProgramRunner#self.call if"
          ::Kernel.exec(env, cmdline[0], *cmdline.drop(1), **options)
        else
          Hip.logger.debug "Hip.Command.ProgramRunner#self.call else"
          # provision 오류시 뭘 할 수 있나?
          ::Kernel.exec(env, cmdline, **options)
        end
      end
    end

    class SubprocessRunner
      def self.call(cmdline, env: {}, panic: true, **options)
        Hip.logger.debug "Hip.Command.SubprocessRunner#self.call >>>>>>>>>>"
        Hip.logger.debug "Hip.Command.SubprocessRunner#self.call cmdline: #{cmdline}"
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
        Hip.logger.debug "Hip.Command#run >>>>>>>>>>"
        cmd = Hip.env.interpolate(cmd)
        argv = [argv] if argv.is_a?(String)
        argv = argv.map { |arg| Hip.env.interpolate(arg) }
        cmdline = [cmd, *argv].compact
        cmdline = cmdline.join(" ").strip if shell

        # Show command to users in debug mode
        if Hip.debug?
          puts "\n" + "=" * 80
          puts "🔍 DEBUG: Executing command"
          puts "=" * 80
          puts "Command: #{cmdline}"
          puts "=" * 80 + "\n"
        end

        Hip.logger.debug "Hip.Command#run cmdline: #{cmdline}"
        Hip.logger.debug "Hip.Command#run env vars: #{Hip.env.vars.inspect}"

        runner.call(cmdline, env: Hip.env.vars, **options)
      end
    end
  end
end
