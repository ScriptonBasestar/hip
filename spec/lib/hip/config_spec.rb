# frozen_string_literal: true

describe Hip::Config do
  subject { described_class.new }

  describe "#exist?" do
    context "when file exists" do
      it { is_expected.to be_exist }
    end

    context "when file doesn't exist", :env do
      let(:env) { {"HIP_FILE" => "no.yml"} }

      it { is_expected.not_to be_exist }
    end
  end

  %i[environment compose infra interaction provision].each do |key|
    describe "##{key}" do
      context "when config file doesn't exist", :env do
        let(:env) { {"HIP_FILE" => "no.yml"} }

        it { expect { subject.public_send(key) }.to raise_error(Hip::Error) }
      end

      context "when config exists" do
        it { expect(subject.public_send(key)).not_to be_nil }
      end

      context "when config is missing" do
        let(:env) { {"HIP_FILE" => fixture_path("missing", "hip.yml")} }

        it { expect(subject.public_send(key)).not_to be_nil }
      end
    end
  end

  context "when config has override file", :env do
    let(:env) { {"HIP_FILE" => fixture_path("overridden", "hip.yml")} }

    it "rewrites an array" do
      expect(subject.compose[:files]).to eq ["docker-compose.local.yml"]
    end

    it "deep merges hashes" do
      expect(subject.interaction[:app]).to include(
        service: "backend",
        subcommands: {
          start: {command: "exec start"},
          debug: {command: "exec debug"}
        }
      )
    end
  end

  context "when config has modules", :env do
    let(:env) { {"HIP_FILE" => fixture_path("modules", "hip.yml")} }

    it "expands modules to main config" do
      expect(subject.interaction[:app][:service]).to eq "backend"
    end

    it "merges modules to main config" do
      expect(subject.interaction[:app1][:service]).to eq "frontend"
    end

    it "overrides first defined module with the last one" do
      expect(subject.interaction[:test_app][:service]).to eq "test_frontend"
    end
  end

  context "when config has unknown module", :env do
    let(:env) { {"HIP_FILE" => fixture_path("unknown_module", "hip.yml")} }

    it "raises and error" do
      expect { subject.interaction }.to raise_error(Hip::Error, /Could not find module/)
    end
  end

  context "when config located two levels higher and overridden at one level higher", :env do
    subject { described_class.new(fixture_path("cascade", "sub_a", "sub_b")) }

    let(:env) { {"HIP_FILE" => nil} }

    it "rewrites an array" do
      expect(subject.compose[:files]).to eq ["docker-compose.local.yml"]
    end

    it "deep merges hashes" do
      expect(subject.interaction[:app]).to include(
        service: "backend",
        compose: {run_options: ["publish=80"]},
        subcommands: {
          start: {command: "exec start", compose: {run_options: ["no-deps"]}},
          debug: {command: "exec debug"}
        }
      )
    end
  end

  describe "#validate" do
    context "when schema is valid" do
      it "does not raise an error" do
        expect { subject.validate }.not_to raise_error
      end
    end

    context "when schema is invalid", :env do
      let(:env) { {"HIP_FILE" => fixture_path("invalid-with-schema/hip.yml")} }

      it "raises a Hip::Error" do
        expect { subject.validate }.to raise_error(Hip::Error, /Schema validation failed/)
      end
    end

    context "when config file is not found", :env do
      let(:env) { {"HIP_FILE" => "no.yml"} }

      it "raises a Hip::Error" do
        expect { subject.validate }.to raise_error(Hip::Error, /Config file not found/)
      end
    end

    context "when schema file is not found", :env do
      let(:env) { {"HIP_FILE" => fixture_path("no-schema", "hip.yml")} }

      it "does not raise an error" do
        expect { subject.validate }.not_to raise_error
      end
    end
  end

  describe "#format_validation_error" do
    let(:error) { double("ValidationError", message: "The property '#/provision' of type array did not match the following type: object") }
    let(:data) { {provision: ["cmd1", "cmd2"]} }

    it "formats error message with property path" do
      message = subject.send(:format_validation_error, error, data)
      expect(message).to include("Schema validation failed in hip.yml")
      expect(message).to include("Property: provision")
      expect(message).to include("Hint: Run 'hip validate'")
    end
  end

  describe "#extract_property_value" do
    let(:data) { {provision: {default: ["cmd1", "cmd2"]}, interaction: {test: {service: "app"}}} }

    it "extracts nested hash values" do
      value = subject.send(:extract_property_value, data, "provision/default")
      expect(value).to eq(["cmd1", "cmd2"])
    end

    it "extracts array elements" do
      value = subject.send(:extract_property_value, data, "provision/default/0")
      expect(value).to eq("cmd1")
    end

    it "returns nil for missing paths" do
      value = subject.send(:extract_property_value, data, "nonexistent/path")
      expect(value).to be_nil
    end
  end

  describe "#format_yaml_snippet" do
    it "formats nil values" do
      result = subject.send(:format_yaml_snippet, nil)
      expect(result).to eq("  (not found)")
    end

    it "formats small values" do
      result = subject.send(:format_yaml_snippet, ["cmd1", "cmd2"])
      expect(result).to include("cmd1")
      expect(result).to include("cmd2")
    end

    it "truncates large arrays" do
      large_array = (1..15).to_a
      result = subject.send(:format_yaml_snippet, large_array)
      expect(result).to include("more lines)")
    end
  end
end
