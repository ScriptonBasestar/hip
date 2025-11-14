# frozen_string_literal: true

require "spec_helper"
require "hip/devcontainer"

# rubocop:disable RSpec/FilePath, RSpec/SpecFilePathFormat
RSpec.describe Hip::DevContainer do
  let(:config) { instance_double(Hip::Config) }
  let(:devcontainer) { described_class.new(config) }

  describe "#initialize" do
    before do
      allow(config).to receive(:to_h).and_return({})
    end

    it "initializes with a config" do
      expect(devcontainer).to be_a(described_class)
    end
  end

  describe "FEATURE_SHORTCUTS" do
    it "defines common feature shortcuts" do
      expect(Hip::DevContainer::FEATURE_SHORTCUTS["docker-in-docker"]).to eq("ghcr.io/devcontainers/features/docker-in-docker:2")
      expect(Hip::DevContainer::FEATURE_SHORTCUTS["github-cli"]).to eq("ghcr.io/devcontainers/features/github-cli:1")
      expect(Hip::DevContainer::FEATURE_SHORTCUTS["node"]).to eq("ghcr.io/devcontainers/features/node:1")
    end
  end

  describe "#service_name" do
    context "when devcontainer service is configured" do
      before do
        allow(config).to receive_messages(to_h: {devcontainer: {service: "web"}}, devcontainer: {service: "web"})
      end

      it "returns configured service name" do
        expect(devcontainer.service_name).to eq("web")
      end
    end

    context "when devcontainer service is not configured" do
      before do
        allow(config).to receive_messages(to_h: {}, compose: {})
      end

      it "returns default service name" do
        expect(devcontainer.service_name).to eq("app")
      end
    end
  end

  describe "#enabled?" do
    context "when devcontainer is explicitly enabled" do
      before do
        allow(config).to receive_messages(to_h: {devcontainer: {enabled: true}}, devcontainer: {enabled: true})
      end

      it "returns true" do
        expect(devcontainer.enabled?).to be true
      end
    end

    context "when devcontainer is explicitly disabled" do
      before do
        allow(config).to receive_messages(to_h: {devcontainer: {enabled: false}}, devcontainer: {enabled: false})
      end

      it "returns false" do
        expect(devcontainer.enabled?).to be false
      end
    end

    context "when devcontainer section does not exist" do
      before do
        allow(config).to receive(:to_h).and_return({})
      end

      it "returns false" do
        expect(devcontainer.enabled?).to be false
      end
    end
  end

  describe "#generate" do
    let(:devcontainer_path) { Pathname.new(".devcontainer/devcontainer.json") }

    before do
      allow(config).to receive_messages(to_h: {devcontainer: {
                                                 name: "Test Container",
                                                 service: "app",
                                                 features: {
                                                   "docker-in-docker": {}
                                                 }
                                               },
                                               compose: {
                                                 files: ["docker-compose.yml"]
                                               }}, devcontainer: {name: "Test Container",
                                                                  service: "app",
                                                                  features: {
                                                                    "docker-in-docker": {}
                                                                  }}, compose: {files: ["docker-compose.yml"]})
      allow(devcontainer).to receive(:devcontainer_path).and_return(devcontainer_path)
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
    end

    it "generates devcontainer.json file" do
      devcontainer.generate

      expect(FileUtils).to have_received(:mkdir_p).with(".devcontainer")
      expect(File).to have_received(:write).with(devcontainer_path, anything)
    end

    it "expands feature shortcuts in the generated config" do
      generated_content = nil
      allow(File).to receive(:write) do |_path, content|
        generated_content = content
      end

      devcontainer.generate

      json = JSON.parse(generated_content)
      expect(json["features"]).to have_key("ghcr.io/devcontainers/features/docker-in-docker:2")
    end
  end
end
# rubocop:enable RSpec/FilePath, RSpec/SpecFilePathFormat
