# frozen_string_literal: true

require "hip/cli"
require "hip/commands/provision"

describe Hip::Commands::Provision, :config do
  let(:config) { {provision: commands} }
  let(:cli) { Hip::CLI }

  context "when has no any commands" do
    let(:commands) { {} }

    it { expect { cli.start ["provision"] }.not_to raise_error }
  end

  context "when has some commands" do
    let(:commands) { {default: ["dip bundle install"]} }

    before { cli.start ["provision"] }

    it { expected_subprocess("dip bundle install", []) }
  end
end
