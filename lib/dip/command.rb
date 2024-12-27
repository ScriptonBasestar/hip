# frozen_string_literal: true

require "forwardable"

module Dip
  class Command
    extend Forwardable

    def_delegators self, :exec_program, :exec_subprocess

    class ProgramRunner
      def self.call(cmdline, env: {}, **options)
        Dip.logger.debug "Dip.Command.ProgramRunner#self.call >>>>>>>>>>"
        Dip.logger.debug "Dip.Command.ProgramRunner#self.call cmdline: #{cmdline}"
        Dip.logger.debug "Dip.Command.ProgramRunner#self.call env: #{env}"
        Dip.logger.debug "Dip.Command.ProgramRunner#self.call options: #{options}"
        if cmdline.is_a?(Array)
          Dip.logger.debug "Dip.Command.ProgramRunner#self.call if"
          ::Kernel.exec(env, cmdline[0], *cmdline.drop(1), **options)
        else
          Dip.logger.debug "Dip.Command.ProgramRunner#self.call else"
          # provision 오류시 뭘 할 수 있나?
          ::Kernel.exec(env, cmdline, **options)
        end
      end
    end

    class SubprocessRunner
      def self.call(cmdline, env: {}, panic: true, **options)
        Dip.logger.debug "Dip.Command.SubprocessRunner#self.call >>>>>>>>>>"
        Dip.logger.debug "Dip.Command.SubprocessRunner#self.call cmdline: #{cmdline}"
        status = ::Kernel.system(env, cmdline, **options)

        if !status && panic
          raise Dip::Error, "Command '#{cmdline}' executed with error"
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
        Dip.logger.debug "Dip.Command#run >>>>>>>>>>"
        cmd = Dip.env.interpolate(cmd)
        argv = [argv] if argv.is_a?(String)
        argv = argv.map { |arg| Dip.env.interpolate(arg) }
        cmdline = [cmd, *argv].compact
        cmdline = cmdline.join(" ").strip if shell
        Dip.logger.debug "Dip.Command#run cmdline: #{cmdline}"

        Dip.logger.debug "====================================="
        Dip.logger.debug "====================================="
        Dip.logger.debug [Dip.env.vars, cmdline].inspect
        Dip.logger.debug "====================================="
        Dip.logger.debug "====================================="

        runner.call(cmdline, env: Dip.env.vars, **options)
      end
    end
  end
end
