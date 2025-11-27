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

  context "when has string commands (legacy format)" do
    let(:commands) { {default: ["dip bundle install", "echo 'Setup complete'"]} }

    before { cli.start ["provision"] }

    it { expected_subprocess("dip bundle install", []) }
    it { expected_subprocess("echo 'Setup complete'", []) }
  end

  describe "structured commands" do
    context "with echo command" do
      let(:commands) { {default: [{echo: "🚀 Starting setup"}]} }

      before { cli.start ["provision"] }

      it "executes echo with escaped text" do
        # Shellwords.escape converts "🚀 Starting setup" to "🚀\\ Starting\\ setup"
        expect(exec_subprocess_runner).to have_received(:call).with(match(/echo.*Starting.*setup/), kind_of(Hash))
      end
    end

    context "with cmd command" do
      let(:commands) { {default: [{cmd: "docker compose up -d postgres"}]} }

      before { cli.start ["provision"] }

      it { expected_subprocess("docker compose up -d postgres", []) }
    end

    context "with shell command" do
      let(:commands) do
        {
          default: [
            {
              shell: "if [ -f config.yml ]; then echo 'Config exists'; fi"
            }
          ]
        }
      end

      before { cli.start ["provision"] }

      it { expected_subprocess("if [ -f config.yml ]; then echo 'Config exists'; fi", []) }
    end

    context "with sleep command (integer)" do
      let(:commands) { {default: [{sleep: 2}]} }

      it "sleeps for specified seconds" do
        allow(Kernel).to receive(:sleep).with(2)
        cli.start ["provision"]
        expect(Kernel).to have_received(:sleep).with(2)
      end
    end

    context "with sleep command (float)" do
      let(:commands) { {default: [{sleep: 1.5}]} }

      it "sleeps for specified seconds" do
        allow(Kernel).to receive(:sleep).with(1.5)
        cli.start ["provision"]
        expect(Kernel).to have_received(:sleep).with(1.5)
      end
    end

    context "with sleep command (string)" do
      let(:commands) { {default: [{sleep: "3"}]} }

      it "sleeps for specified seconds" do
        allow(Kernel).to receive(:sleep).with(3.0)
        cli.start ["provision"]
        expect(Kernel).to have_received(:sleep).with(3.0)
      end
    end

    context "with docker compose command (string)" do
      let(:commands) { {default: [{docker: {compose: "up -d postgres redis"}}]} }

      before { cli.start ["provision"] }

      it { expected_subprocess("docker compose up -d postgres redis", []) }
    end

    context "with docker compose command (array)" do
      let(:commands) { {default: [{docker: {compose: ["up", "-d", "postgres", "redis"]}}]} }

      before { cli.start ["provision"] }

      it { expected_subprocess("docker compose up -d postgres redis", []) }
    end

    context "with invalid command type" do
      let(:commands) { {default: [{invalid: "command"}]} }

      it "raises error for unknown command type" do
        expect { cli.start ["provision"] }.to raise_error(SystemExit)
      end
    end

    context "with docker command missing compose key" do
      let(:commands) { {default: [{docker: {}}]} }

      it "raises error when docker command lacks compose key" do
        expect { cli.start ["provision"] }.to raise_error(SystemExit)
      end
    end
  end

  context "with mixed command formats" do
    let(:commands) do
      {
        default: [
          "echo 'Starting setup'",
          {echo: "Step 1"},
          {cmd: "docker compose down"},
          {sleep: 2},
          {docker: {compose: "up -d postgres"}},
          "echo 'Setup complete'"
        ]
      }
    end

    before { cli.start ["provision"] }

    it { expected_subprocess("echo 'Starting setup'", []) }
    it { expected_subprocess("docker compose down", []) }
    it { expected_subprocess("docker compose up -d postgres", []) }
    it { expected_subprocess("echo 'Setup complete'", []) }

    it "executes echo with step 1" do
      expect(exec_subprocess_runner).to have_received(:call).with(match(/echo.*Step.*1/), kind_of(Hash))
    end

    it "sleeps between commands" do
      allow(Kernel).to receive(:sleep).with(2)
      cli.start ["provision"]
      expect(Kernel).to have_received(:sleep).with(2)
    end
  end

  context "with custom provision profile" do
    let(:commands) do
      {
        default: [{echo: "Default profile"}],
        custom: [{echo: "Custom profile"}]
      }
    end

    it "executes default profile" do
      expect { cli.start ["provision"] }.not_to raise_error
    end

    it "executes custom profile" do
      expect { cli.start ["provision", "custom"] }.not_to raise_error
    end

    it "raises error for non-existent profile" do
      expect { cli.start ["provision", "nonexistent"] }.to raise_error(SystemExit)
    end
  end
end
