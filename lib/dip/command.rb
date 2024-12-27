# frozen_string_literal: true

require "forwardable"

module Dip
  class Command
    extend Forwardable

    def_delegators self, :exec_program, :exec_subprocess

    class ProgramRunner
      def self.call(cmdline, env: {}, **options)
        puts "Dip.Command.ProgramRunner#self.call >>>>>>>>>>" if Dip.debug?
        puts "Dip.Command.ProgramRunner#self.call cmdline: #{cmdline}" if Dip.debug?
        puts "Dip.Command.ProgramRunner#self.call env: #{env}" if Dip.debug?
        puts "Dip.Command.ProgramRunner#self.call options: #{options}" if Dip.debug?
        if cmdline.is_a?(Array)
          puts "Dip.Command.ProgramRunner#self.call if" if Dip.debug?
          ::Kernel.exec(env, cmdline[0], *cmdline.drop(1), **options)
        else
          puts "Dip.Command.ProgramRunner#self.call else" if Dip.debug?
          # provision 오류시 뭘 할 수 있나?
          ::Kernel.exec(env, cmdline, **options)
        end
      end
    end

    class SubprocessRunner
      def self.call(cmdline, env: {}, panic: true, **options)
        puts "Dip.Command.SubprocessRunner#self.call >>>>>>>>>>" if Dip.debug?
        puts "Dip.Command.SubprocessRunner#self.call cmdline: #{cmdline}" if Dip.debug?
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
        puts "Dip.Command#run >>>>>>>>>>" if Dip.debug?
        cmd = Dip.env.interpolate(cmd)
        argv = [argv] if argv.is_a?(String)
        argv = argv.map { |arg| Dip.env.interpolate(arg) }
        cmdline = [cmd, *argv].compact
        cmdline = cmdline.join(" ").strip if shell
        puts "Dip.Command#run cmdline: #{cmdline}"

        puts "=====================================" if Dip.debug?
        puts "=====================================" if Dip.debug?
        puts [Dip.env.vars, cmdline].inspect if Dip.debug?
        puts "=====================================" if Dip.debug?
        puts "=====================================" if Dip.debug?

        runner.call(cmdline, env: Dip.env.vars, **options)
      end
    end
  end
end
