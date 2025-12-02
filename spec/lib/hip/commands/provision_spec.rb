# frozen_string_literal: true

require "hip/cli"
require "hip/commands/provision"
require "hip/commands/compose"

describe Hip::Commands::Provision, :config do
  let(:config) { {provision: commands} }
  let(:cli) { Hip::CLI }

  # Mock container check to skip auto-up by default in all tests
  before do
    allow_any_instance_of(Hip::Commands::Provision).to receive(:any_containers_running?).and_return(true)
  end

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

  describe "auto-start containers" do
    let(:commands) do
      {
        default: [
          {echo: "Starting initialization..."},
          {cmd: "bundle install"}
        ]
      }
    end

    let(:provision_instance) { Hip::Commands::Provision.new([]) }

    context "when no containers are running" do
      before do
        # Mock container check to return false (no containers running)
        allow_any_instance_of(Hip::Commands::Provision).to receive(:any_containers_running?).and_return(false)
        # Mock Compose command to prevent actual execution
        allow(Hip::Commands::Compose).to receive(:new).and_return(double(execute: true))
      end

      it "automatically starts containers with 'up -d --wait'" do
        expect(Hip::Commands::Compose).to receive(:new).with("up", "-d", "--wait")
        cli.start ["provision"]
      end
    end

    context "when containers are already running" do
      before do
        # Mock container check to return true (containers running)
        allow_any_instance_of(Hip::Commands::Provision).to receive(:any_containers_running?).and_return(true)
      end

      it "skips starting containers" do
        expect(Hip::Commands::Compose).not_to receive(:new)
        cli.start ["provision"]
      end
    end
  end

  describe "workflow integration" do
    context "when provision expects containers to be running" do
      let(:commands) do
        {
          default: [
            {echo: "Starting initialization..."},
            {cmd: "bundle install"},
            {cmd: "rails db:create"},
            {cmd: "rails db:migrate"},
            {echo: "Setup complete!"}
          ]
        }
      end

      before { cli.start ["provision"] }

      it "executes initialization commands without container management" do
        expected_subprocess("bundle install", [])
        expected_subprocess("rails db:create", [])
        expected_subprocess("rails db:migrate", [])
      end
    end

    context "when provision workflow is documented correctly" do
      let(:commands) do
        {
          default: [
            {echo: "Note: Ensure containers are running (hip up -d)"},
            {cmd: "npm install"},
            {cmd: "npm run build"}
          ]
        }
      end

      before { cli.start ["provision"] }

      it "reminds user about container requirements" do
        expect(exec_subprocess_runner).to have_received(:call)
          .with(match(/ensure.*containers.*running/i), kind_of(Hash))
      end

      it "executes initialization tasks" do
        expected_subprocess("npm install", [])
        expected_subprocess("npm run build", [])
      end
    end
  end
end
