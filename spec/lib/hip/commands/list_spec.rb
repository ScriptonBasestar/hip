# frozen_string_literal: true

require "spec_helper"
require "hip/commands/list"
require "json"
require "yaml"

RSpec.describe Hip::Commands::List do
  let(:cli_config) do
    {
      interaction: {
        shell: {
          description: "Open bash shell",
          service: "web",
          command: "/bin/bash",
          shell: true
        },
        rails: {
          description: "Run Rails commands",
          service: "web",
          command: "bundle exec rails",
          subcommands: {
            console: {
              description: "Start Rails console",
              command: "console"
            },
            server: {
              description: "Start Rails server",
              command: "server"
            }
          }
        },
        test: {
          description: "Run tests",
          pod: "app",
          command: "npm test"
        },
        lint: {
          description: "Run linter",
          command: "npm run lint"
        }
      }
    }
  end

  before do
    allow(Hip).to receive(:config).and_return(
      double(interaction: cli_config[:interaction], exist?: true)
    )
  end

  describe "#execute with default format (table)" do
    it "prints all run commands" do
      output = capture_stdout { described_class.new.execute }

      expect(output).to include("shell")
      expect(output).to include("rails")
      expect(output).to include("test")
      expect(output).to include("lint")
    end

    it "includes command descriptions" do
      output = capture_stdout { described_class.new.execute }

      expect(output).to include("Open bash shell")
      expect(output).to include("Run Rails commands")
      expect(output).to include("Run tests")
    end

    it "includes subcommands" do
      output = capture_stdout { described_class.new.execute }

      expect(output).to include("rails console")
      expect(output).to include("Start Rails console")
      expect(output).to include("rails server")
    end
  end

  describe "#execute with format: json" do
    it "outputs valid JSON" do
      output = capture_stdout { described_class.new(format: "json").execute }

      expect { JSON.parse(output) }.not_to raise_error
    end

    it "includes all commands in JSON" do
      output = capture_stdout { described_class.new(format: "json").execute }
      json = JSON.parse(output)

      expect(json).to include("shell", "rails", "test", "lint")
    end

    it "includes command metadata" do
      output = capture_stdout { described_class.new(format: "json").execute }
      json = JSON.parse(output)

      shell_cmd = json["shell"]
      expect(shell_cmd).to include(
        "description" => "Open bash shell",
        "command" => "/bin/bash",
        "runner" => "DockerCompose",
        "service" => "web"
      )
    end

    it "includes shell mode in metadata" do
      output = capture_stdout { described_class.new(format: "json").execute }
      json = JSON.parse(output)

      expect(json["shell"]["shell"]).to be true
    end

    it "identifies kubectl runner for pod commands" do
      output = capture_stdout { described_class.new(format: "json").execute }
      json = JSON.parse(output)

      test_cmd = json["test"]
      expect(test_cmd["runner"]).to eq("Kubectl")
      expect(test_cmd["pod"]).to eq("app")
    end

    it "identifies local runner for commands without service/pod" do
      output = capture_stdout { described_class.new(format: "json").execute }
      json = JSON.parse(output)

      lint_cmd = json["lint"]
      expect(lint_cmd["runner"]).to eq("Local")
    end

    it "includes subcommands in JSON" do
      output = capture_stdout { described_class.new(format: "json").execute }
      json = JSON.parse(output)

      expect(json).to include("rails console", "rails server")
      expect(json["rails console"]["description"]).to eq("Start Rails console")
    end
  end

  describe "#execute with format: yaml" do
    it "outputs valid YAML" do
      output = capture_stdout { described_class.new(format: "yaml").execute }

      expect { YAML.safe_load(output, permitted_classes: [Symbol]) }.not_to raise_error
    end

    it "includes all commands in YAML" do
      output = capture_stdout { described_class.new(format: "yaml").execute }
      yaml = YAML.safe_load(output, permitted_classes: [Symbol])

      expect(yaml).to include("shell", "rails", "test", "lint")
    end

    it "includes command metadata in YAML" do
      output = capture_stdout { described_class.new(format: "yaml").execute }
      yaml = YAML.safe_load(output, permitted_classes: [Symbol])

      shell_cmd = yaml["shell"]
      expect(shell_cmd[:description]).to eq("Open bash shell")
      expect(shell_cmd[:command]).to eq("/bin/bash")
      expect(shell_cmd[:runner]).to eq("DockerCompose")
    end
  end

  describe "#execute with detailed: true" do
    it "includes runner type in output" do
      output = capture_stdout { described_class.new(detailed: true).execute }

      # Check that detailed info is present (runner info, service/pod, commands)
      expect(output).to match(/\[DockerCompose\]|\[Kubectl\]|\[Local\]/)
    end

    it "includes service/pod target information" do
      output = capture_stdout { described_class.new(detailed: true).execute }

      expect(output).to include("service:web")
      expect(output).to include("pod:app")
    end

    it "includes actual command" do
      output = capture_stdout { described_class.new(detailed: true).execute }

      expect(output).to include("/bin/bash")
      expect(output).to include("bundle exec rails")
      expect(output).to include("npm test")
    end
  end

  describe "#execute with format: json and detailed: true" do
    it "includes detailed metadata in JSON" do
      output = capture_stdout do
        described_class.new(format: "json", detailed: true).execute
      end
      json = JSON.parse(output)

      shell_cmd = json["shell"]
      expect(shell_cmd).to include(
        "runner",
        "service",
        "command",
        "description"
      )
    end
  end

  describe "edge cases" do
    it "handles empty interaction config" do
      allow(Hip).to receive(:config).and_return(
        double(interaction: {}, exist?: true)
      )

      output = capture_stdout { described_class.new.execute }
      expect(output).to be_empty
    end

    it "handles commands without descriptions" do
      allow(Hip).to receive(:config).and_return(
        double(interaction: {
          test: {
            service: "app",
            command: "npm test"
          }
        }, exist?: true)
      )

      output = capture_stdout { described_class.new.execute }
      expect(output).to include("test")
    end

    it "handles invalid format gracefully" do
      # Should default to table format
      output = capture_stdout { described_class.new(format: "invalid").execute }

      expect(output).to_not be_empty
      # Should not be JSON or YAML
      expect { JSON.parse(output) }.to raise_error(JSON::ParserError)
    end
  end

  # Helper method to capture stdout
  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
