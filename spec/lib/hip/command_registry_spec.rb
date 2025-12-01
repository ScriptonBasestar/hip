# frozen_string_literal: true

require "spec_helper"
require "hip/command_registry"
require "json"
require "yaml"

RSpec.describe Hip::CommandRegistry do
  describe ".manifest" do
    it "generates complete manifest structure" do
      manifest = described_class.manifest

      expect(manifest).to include(
        :hip_version,
        :schema_version,
        :generated_at,
        :config_file,
        :static_commands,
        :subcommand_groups,
        :dynamic_commands,
        :runners
      )
    end

    it "includes correct Hip version" do
      manifest = described_class.manifest
      expect(manifest[:hip_version]).to eq(Hip::VERSION)
    end

    it "includes schema version" do
      manifest = described_class.manifest
      expect(manifest[:schema_version]).to eq("1.0")
    end

    it "includes ISO8601 timestamp" do
      manifest = described_class.manifest
      expect(manifest[:generated_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "includes config file path when config exists" do
      # This test runs in context where hip.yml exists
      manifest = described_class.manifest
      expect(manifest[:config_file]).to be_a(String)
    end

    it "includes static commands with metadata" do
      manifest = described_class.manifest
      static_commands = manifest[:static_commands]

      expect(static_commands).to include(:version, :ls, :compose, :run, :manifest)

      # Check version command structure
      expect(static_commands[:version]).to include(
        description: "Show Hip version",
        type: :builtin
      )

      # Check ls command structure
      expect(static_commands[:ls]).to include(
        description: "List available run commands",
        type: :builtin
      )
    end

    it "includes subcommand groups with nested commands" do
      manifest = described_class.manifest
      groups = manifest[:subcommand_groups]

      expect(groups).to include(:ssh, :infra, :console, :devcontainer, :claude)

      # Check ssh group structure
      ssh_group = groups[:ssh]
      expect(ssh_group).to include(:description, :commands)
      expect(ssh_group[:commands]).to include(:up, :down, :restart, :status)

      # Check devcontainer group structure
      dc_group = groups[:devcontainer]
      expect(dc_group[:commands]).to include(:init, :sync, :validate, :bash)
    end

    it "includes runner metadata" do
      manifest = described_class.manifest
      runners = manifest[:runners]

      expect(runners).to include(:docker_compose, :kubectl, :local)

      # Check docker_compose runner
      docker_compose = runners[:docker_compose]
      expect(docker_compose[:trigger]).to include("service key present")
      expect(docker_compose[:file]).to include("docker_compose_runner.rb")

      # Check kubectl runner
      kubectl = runners[:kubectl]
      expect(kubectl[:trigger]).to include("pod key present")
      expect(kubectl[:file]).to include("kubectl_runner.rb")
    end

    it "includes dynamic commands from hip.yml if config exists" do
      # This test uses the actual hip.yml in the project
      manifest = described_class.manifest
      dynamic = manifest[:dynamic_commands]

      expect(dynamic).to be_a(Hash)
      # May be empty if no hip.yml, or contain commands if present
    end
  end

  describe ".to_json" do
    it "returns valid JSON string" do
      json_str = described_class.to_json
      expect { JSON.parse(json_str) }.not_to raise_error
    end

    it "includes all manifest keys in JSON" do
      json_str = described_class.to_json
      parsed = JSON.parse(json_str)

      expect(parsed).to include(
        "hip_version",
        "schema_version",
        "generated_at",
        "static_commands",
        "subcommand_groups",
        "runners"
      )
    end

    it "formats JSON with pretty print" do
      json_str = described_class.to_json
      # Pretty printed JSON should have newlines and indentation
      expect(json_str).to include("\n")
      expect(json_str.lines.count).to be > 10
    end
  end

  describe ".to_yaml" do
    it "returns valid YAML string" do
      yaml_str = described_class.to_yaml
      expect { YAML.safe_load(yaml_str, permitted_classes: [Symbol, Time]) }.not_to raise_error
    end

    it "includes all manifest keys in YAML" do
      yaml_str = described_class.to_yaml
      parsed = YAML.safe_load(yaml_str, permitted_classes: [Symbol, Time])

      expect(parsed.keys).to include(
        :hip_version,
        :schema_version,
        :generated_at,
        :static_commands,
        :subcommand_groups,
        :runners
      )
    end
  end

  describe "STATIC_COMMANDS" do
    it "defines essential built-in commands" do
      expect(described_class::STATIC_COMMANDS).to include(
        :version,
        :ls,
        :compose,
        :run,
        :provision,
        :validate,
        :manifest
      )
    end

    it "includes aliases for version command" do
      version_cmd = described_class::STATIC_COMMANDS[:version]
      expect(version_cmd[:aliases]).to eq(%w[--version -v])
    end

    it "includes options for ls command" do
      ls_cmd = described_class::STATIC_COMMANDS[:ls]
      expect(ls_cmd[:options]).to include(
        format: "Output format (table, json, yaml)",
        detailed: "Show detailed information"
      )
    end
  end

  describe "SUBCOMMAND_GROUPS" do
    it "defines all subcommand groups" do
      expect(described_class::SUBCOMMAND_GROUPS).to include(
        :ssh,
        :infra,
        :console,
        :devcontainer,
        :claude
      )
    end

    it "includes commands for ssh group" do
      ssh_group = described_class::SUBCOMMAND_GROUPS[:ssh]
      expect(ssh_group[:commands]).to include(:up, :down, :restart, :status)
    end

    it "includes commands for devcontainer group" do
      dc_group = described_class::SUBCOMMAND_GROUPS[:devcontainer]
      expect(dc_group[:commands]).to include(
        :init,
        :sync,
        :validate,
        :bash,
        :provision,
        :features,
        :info
      )
    end
  end

  describe "RUNNERS" do
    it "defines all runner types" do
      expect(described_class::RUNNERS).to include(
        :docker_compose,
        :kubectl,
        :local
      )
    end

    it "includes trigger conditions for each runner" do
      described_class::RUNNERS.each do |_name, metadata|
        expect(metadata).to include(:trigger, :file)
      end
    end
  end
end
