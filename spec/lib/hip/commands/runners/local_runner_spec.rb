# frozen_string_literal: true

require "shellwords"
require "hip/cli"
require "hip/commands/run"

describe Hip::Commands::Runners::LocalRunner, :config do
  let(:config) { {interaction: commands} }
  let(:commands) do
    {
      setup: {command: "./bin/setup", default_args: "all"}
    }
  end
  let(:cli) { Hip::CLI }

  context "when using default args" do
    before { cli.start "run setup".shellsplit }

    it { expected_exec("./bin/setup", ["all"]) }
  end

  context "when args are provided" do
    before { cli.start "run setup db".shellsplit }

    it { expected_exec("./bin/setup", ["db"]) }
  end
end
