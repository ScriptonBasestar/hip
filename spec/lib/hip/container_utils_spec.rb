# frozen_string_literal: true

require "hip/container_utils"

describe Hip::ContainerUtils do
  before do
    described_class.clear_cache
    allow(Hip.logger).to receive(:debug)
  end

  describe ".any_containers_running?" do
    context "when no containers exist" do
      before do
        allow(described_class).to receive(:`).and_return("")
      end

      it "returns false" do
        expect(described_class.any_containers_running?).to be false
      end
    end

    context "when containers are running" do
      before do
        json_output = <<~JSON.strip
          {"ID":"abc123","Name":"test_app","State":"running","Project":"test-project"}
        JSON
        allow(described_class).to receive(:`).and_return(json_output)
      end

      it "returns true" do
        expect(described_class.any_containers_running?).to be true
      end
    end

    context "when containers exist but not running" do
      before do
        json_output = '{"ID":"abc123","Name":"test_app","State":"exited","Project":"test-project"}'
        allow(described_class).to receive(:`).and_return(json_output)
      end

      it "returns false" do
        expect(described_class.any_containers_running?).to be false
      end
    end

    context "when JSON parsing fails" do
      before do
        allow(described_class).to receive(:`).and_return("not valid json")
      end

      it "returns false" do
        expect(described_class.any_containers_running?).to be false
      end
    end
  end

  describe ".service_running_project" do
    context "when service is not running" do
      before do
        allow(described_class).to receive(:`).and_return("")
      end

      it "returns nil" do
        expect(described_class.service_running_project("app")).to be_nil
      end
    end

    context "when service is running" do
      before do
        json_output = '{"ID":"abc123","Name":"test_app","State":"running","Project":"test-project"}'
        allow(described_class).to receive(:`).and_return(json_output)
      end

      it "returns project name" do
        expect(described_class.service_running_project("app")).to eq("test-project")
      end
    end

    context "when service exists but not running" do
      before do
        json_output = '{"ID":"abc123","Name":"test_app","State":"exited","Project":"test-project"}'
        allow(described_class).to receive(:`).and_return(json_output)
      end

      it "returns nil" do
        expect(described_class.service_running_project("app")).to be_nil
      end
    end

    context "when state is uppercase" do
      before do
        json_output = '{"ID":"abc123","Name":"test_app","State":"RUNNING","Project":"test-project"}'
        allow(described_class).to receive(:`).and_return(json_output)
      end

      it "handles case insensitively" do
        expect(described_class.service_running_project("app")).to eq("test-project")
      end
    end
  end

  describe "caching" do
    before do
      json_output = '{"ID":"abc123","Name":"test_app","State":"running","Project":"test-project"}'
      allow(described_class).to receive(:`).and_return(json_output)
    end

    it "caches container detection results" do
      # First call
      result1 = described_class.service_running_project("app")

      # Reset the mock to verify second call doesn't hit it
      expect(described_class).not_to receive(:`).with(/app/)

      # Second call should use cache
      result2 = described_class.service_running_project("app")

      expect(result1).to eq("test-project")
      expect(result2).to eq("test-project")
    end

    it "expires cache after TTL" do
      # First call
      result1 = described_class.service_running_project("app")
      expect(result1).to eq("test-project")

      # Simulate time passage beyond TTL
      allow(Time).to receive(:now).and_return(Time.now + Hip::ContainerUtils::CACHE_TTL + 1)

      # Should query docker again
      new_output = '{"ID":"xyz789","Name":"test_app","State":"running","Project":"new-project"}'
      allow(described_class).to receive(:`).and_return(new_output)

      result2 = described_class.service_running_project("app")
      expect(result2).to eq("new-project")
    end
  end

  describe ".clear_cache" do
    it "clears the cache" do
      json_output = '{"ID":"abc123","Name":"test_app","State":"running","Project":"test-project"}'
      allow(described_class).to receive(:`).and_return(json_output)

      # Populate cache
      described_class.service_running_project("app")

      # Clear cache
      described_class.clear_cache

      # Should query again
      expect(described_class).to receive(:`).and_return(json_output)
      described_class.service_running_project("app")
    end
  end

  describe ".detect_container_name_usage" do
    def fixtures_base_path
      Pathname.new(File.expand_path("../../fixtures", __dir__))
    end

    before do
      described_class.clear_cache
      allow(Hip.env).to receive(:interpolate) { |v| v }
    end

    context "when compose files have container_name" do
      before do
        config_path = fixtures_base_path.join("container_name_conflict/hip.yml")
        allow(Hip.config).to receive_messages(file_path: config_path, compose: {
          files: ["docker-compose.yml"],
          project_name: "test-project"
        })
      end

      it "returns detection result with services" do
        result = described_class.detect_container_name_usage

        expect(result).not_to be_nil
        expect(result[:services]).to eq({
          "app" => "fixed_app_container",
          "postgres" => "fixed_postgres_container"
        })
        expect(result[:project_name]).to eq("test-project")
      end

      it "caches the result" do
        result1 = described_class.detect_container_name_usage
        result2 = described_class.detect_container_name_usage

        expect(result1).to equal(result2)
      end
    end

    context "when compose files have no container_name" do
      before do
        config_path = fixtures_base_path.join("no_container_name/hip.yml")
        allow(Hip.config).to receive_messages(file_path: config_path, compose: {
          files: ["docker-compose.yml"]
        })
      end

      it "returns nil" do
        result = described_class.detect_container_name_usage

        expect(result).to be_nil
      end
    end

    context "when compose config is empty" do
      before do
        allow(Hip.config).to receive(:compose).and_return({})
      end

      it "returns nil" do
        result = described_class.detect_container_name_usage

        expect(result).to be_nil
      end
    end
  end

  describe ".warn_container_name_usage" do
    def fixtures_base_path
      Pathname.new(File.expand_path("../../fixtures", __dir__))
    end

    before do
      described_class.clear_cache
      allow(Hip.env).to receive(:interpolate) { |v| v }
    end

    context "when container_name is detected with project_name" do
      before do
        config_path = fixtures_base_path.join("container_name_conflict/hip.yml")
        allow(Hip.config).to receive_messages(file_path: config_path, compose: {
          files: ["docker-compose.yml"],
          project_name: "test-project"
        })
      end

      it "outputs warning to stderr" do
        expect { described_class.warn_container_name_usage }
          .to output(/WARNING: container_name detected/).to_stderr
      end

      it "includes project_name in warning" do
        expect { described_class.warn_container_name_usage }
          .to output(/Hip project_name: "test-project"/).to_stderr
      end

      it "includes service names in warning" do
        expect { described_class.warn_container_name_usage }
          .to output(/app: "fixed_app_container"/).to_stderr
      end

      it "returns true" do
        # Suppress stderr output
        allow($stderr).to receive(:write)
        expect(described_class.warn_container_name_usage).to be true
      end
    end

    context "when container_name is detected without project_name" do
      before do
        config_path = fixtures_base_path.join("container_name_conflict/hip.yml")
        allow(Hip.config).to receive_messages(file_path: config_path, compose: {
          files: ["docker-compose.yml"]
        })
      end

      it "outputs warning with auto-detection note" do
        expect { described_class.warn_container_name_usage }
          .to output(/auto-detection.*works normally/).to_stderr
      end
    end

    context "when no container_name is detected" do
      before do
        config_path = fixtures_base_path.join("no_container_name/hip.yml")
        allow(Hip.config).to receive_messages(file_path: config_path, compose: {
          files: ["docker-compose.yml"]
        })
      end

      it "returns false" do
        expect(described_class.warn_container_name_usage).to be false
      end

      it "does not output anything" do
        expect { described_class.warn_container_name_usage }
          .not_to output.to_stderr
      end
    end
  end
end
