# frozen_string_literal: true

require "shellwords"
require "hip/cli"
require "hip/commands/clean"

describe Hip::Commands::Clean do
  let(:cli) { Hip::CLI }

  context "when executing with force flag" do
    before { cli.start "clean -f".shellsplit }

    it "runs compose down with remove-orphans" do
      expected_exec("docker", ["compose", "down", "--remove-orphans"])
    end
  end

  context "when executing with volumes flag" do
    before { cli.start "clean -f -v".shellsplit }

    it "runs compose down with volumes and remove-orphans" do
      expected_exec("docker", ["compose", "down", "--remove-orphans", "--volumes"])
    end
  end

  context "when executing with images flag" do
    before { cli.start "clean -f -i".shellsplit }

    it "runs compose down with rmi all and remove-orphans" do
      expected_exec("docker", ["compose", "down", "--remove-orphans", "--rmi", "all"])
    end
  end

  context "when executing with all flags" do
    before { cli.start "clean -f -v -i".shellsplit }

    it "runs compose down with all cleanup options" do
      expected_exec("docker", ["compose", "down", "--remove-orphans", "--volumes", "--rmi", "all"])
    end
  end
end
