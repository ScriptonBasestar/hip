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
end
