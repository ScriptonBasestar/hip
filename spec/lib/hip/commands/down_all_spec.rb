# frozen_string_literal: true

require "shellwords"
require "hip/cli"
require "hip/commands/down_all"

describe Hip::Commands::DownAll do
  let(:cli) { Hip::CLI }

  before { cli.start "down -A".shellsplit }

  it "runs a valid command" do
    expected_subprocess(
      "docker rm --volumes $(docker stop $(docker ps --filter 'label=com.docker.compose.project' -q))",
      []
    )
  end
end
