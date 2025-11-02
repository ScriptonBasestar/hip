# frozen_string_literal: true

require "forwardable"

module Hip
  class Command
    extend Forwardable

    def_delegators self, :exec_program, :exec_subprocess

    class ProgramRunner
      def self.call(cmdline, env: {}, **options)
        Hip.logger.debug "Dip.Command.ProgramRunner#self.call >>>>>>>>>>"
        Hip.logger.debug "Dip.Command.ProgramRunner#self.call cmdline: #{cmdline}"
        Hip.logger.debug "Dip.Command.ProgramRunner#self.call env: #{env}"
        Hip.logger.debug "Dip.Command.ProgramRunner#self.call options: #{options}"
        if cmdline.is_a?(Array)
          Hip.logger.debug "Dip.Command.ProgramRunner#self.call if"
          ::Kernel.exec(env, cmdline[0], *cmdline.drop(1), **options)
        else
          Hip.logger.debug "Dip.Command.ProgramRunner#self.call else"
          # provision 오류시 뭘 할 수 있나?
          ::Kernel.exec(env, cmdline, **options)
        end
      end
    end

    class SubprocessRunner
      def self.call(cmdline, env: {}, panic: true, **options)
        Hip.logger.debug "Dip.Command.SubprocessRunner#self.call >>>>>>>>>>"
        Hip.logger.debug "Dip.Command.SubprocessRunner#self.call cmdline: #{cmdline}"
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
        Hip.logger.debug "Dip.Command#run >>>>>>>>>>"
        cmd = Hip.env.interpolate(cmd)
        argv = [argv] if argv.is_a?(String)
        argv = argv.map { |arg| Hip.env.interpolate(arg) }
        cmdline = [cmd, *argv].compact
        cmdline = cmdline.join(" ").strip if shell
        Hip.logger.debug "Dip.Command#run cmdline: #{cmdline}"

        Hip.logger.debug "====================================="
        Hip.logger.debug "====================================="
        Hip.logger.debug [Hip.env.vars, cmdline].inspect
        Hip.logger.debug "====================================="
        Hip.logger.debug "====================================="

        runner.call(cmdline, env: Hip.env.vars, **options)
      end
    end
  end
end
