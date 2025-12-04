# frozen_string_literal: true

require "hip/compose_file_parser"

describe Hip::ComposeFileParser do
  def fixtures_base_path
    Pathname.new(File.expand_path("../../fixtures", __dir__))
  end

  before do
    allow(Hip.logger).to receive(:debug)
  end

  describe "#services_with_container_name" do
    context "when compose file has container_name" do
      before do
        config_path = fixtures_base_path.join("container_name_conflict/hip.yml")
        allow(Hip.config).to receive(:file_path).and_return(config_path)
        allow(Hip.env).to receive(:interpolate) { |v| v }
      end

      let(:compose_config) do
        {
          files: ["docker-compose.yml"],
          project_name: "test-project"
        }
      end

      it "returns services with their container_name values" do
        parser = described_class.new(compose_config)
        result = parser.services_with_container_name

        expect(result).to eq({
          "app" => "fixed_app_container",
          "postgres" => "fixed_postgres_container"
        })
      end

      it "does not include services without container_name" do
        parser = described_class.new(compose_config)
        result = parser.services_with_container_name

        expect(result.keys).not_to include("redis")
      end

      it "has_container_names? returns true" do
        parser = described_class.new(compose_config)
        expect(parser.has_container_names?).to be true
      end
    end

    context "when compose file has no container_name" do
      before do
        config_path = fixtures_base_path.join("no_container_name/hip.yml")
        allow(Hip.config).to receive(:file_path).and_return(config_path)
        allow(Hip.env).to receive(:interpolate) { |v| v }
      end

      let(:compose_config) do
        {
          files: ["docker-compose.yml"]
        }
      end

      it "returns empty hash" do
        parser = described_class.new(compose_config)
        result = parser.services_with_container_name

        expect(result).to be_empty
      end

      it "has_container_names? returns false" do
        parser = described_class.new(compose_config)
        expect(parser.has_container_names?).to be false
      end
    end

    context "when compose files are not specified" do
      before do
        config_path = fixtures_base_path.join("container_name_conflict/hip.yml")
        allow(Hip.config).to receive(:file_path).and_return(config_path)
        allow(Hip.env).to receive(:interpolate) { |v| v }
      end

      it "uses default compose file if it exists" do
        parser = described_class.new({})
        # Default should find docker-compose.yml in the fixture directory
        expect(parser.compose_files).not_to be_empty
      end
    end

    context "when compose file does not exist" do
      before do
        config_path = fixtures_base_path.join("empty/hip.yml")
        allow(Hip.config).to receive(:file_path).and_return(config_path)
        allow(Hip.env).to receive(:interpolate) { |v| v }
      end

      let(:compose_config) do
        {
          files: ["nonexistent-compose.yml"]
        }
      end

      it "returns empty hash" do
        parser = described_class.new(compose_config)
        result = parser.services_with_container_name

        expect(result).to be_empty
      end
    end

    context "when compose file has invalid YAML" do
      before do
        config_path = fixtures_base_path.join("container_name_conflict/hip.yml")
        allow(Hip.config).to receive(:file_path).and_return(config_path)
        allow(Hip.env).to receive(:interpolate) { |v| v }
        allow(File).to receive(:read).and_return("invalid: yaml: content: [")
      end

      let(:compose_config) do
        {
          files: ["docker-compose.yml"]
        }
      end

      it "handles error gracefully and returns empty hash" do
        parser = described_class.new(compose_config)
        result = parser.services_with_container_name

        expect(result).to be_empty
      end
    end
  end

  describe "#compose_files" do
    before do
      config_path = fixtures_base_path.join("container_name_conflict/hip.yml")
      allow(Hip.config).to receive(:file_path).and_return(config_path)
      allow(Hip.env).to receive(:interpolate) { |v| v }
    end

    it "resolves relative paths from hip.yml directory" do
      compose_config = { files: ["docker-compose.yml"] }
      parser = described_class.new(compose_config)

      expect(parser.compose_files.first.to_s).to include("container_name_conflict/docker-compose.yml")
    end

    it "filters out non-existent files" do
      compose_config = { files: ["docker-compose.yml", "nonexistent.yml"] }
      parser = described_class.new(compose_config)

      expect(parser.compose_files.size).to eq(1)
    end
  end

  describe "#services" do
    before do
      config_path = fixtures_base_path.join("container_name_conflict/hip.yml")
      allow(Hip.config).to receive(:file_path).and_return(config_path)
      allow(Hip.env).to receive(:interpolate) { |v| v }
    end

    it "returns all services from compose file" do
      compose_config = { files: ["docker-compose.yml"] }
      parser = described_class.new(compose_config)

      expect(parser.services.keys).to contain_exactly("app", "postgres", "redis")
    end

    it "caches parsed services" do
      compose_config = { files: ["docker-compose.yml"] }
      parser = described_class.new(compose_config)

      services1 = parser.services
      services2 = parser.services

      expect(services1).to equal(services2) # Same object reference
    end
  end
end
