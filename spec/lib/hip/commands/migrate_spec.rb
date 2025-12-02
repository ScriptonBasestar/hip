# frozen_string_literal: true

require "spec_helper"
require "hip/commands/migrate"

RSpec.describe Hip::Commands::Migrate do
  describe "#execute" do
    context "when migration is needed" do
      it "generates migration guide" do
        output = capture_stdout { described_class.new.execute }

        expect(output).to include("Hip Configuration Migration Guide")
        expect(output).to include("Migration Required**: YES")
      end

      it "includes current and target versions" do
        output = capture_stdout { described_class.new.execute }

        expect(output).to include("Current Version")
        expect(output).to include("Latest Version**: #{Hip::VERSION}")
      end

      it "includes migration checklist" do
        output = capture_stdout { described_class.new.execute }

        expect(output).to include("Migration Checklist")
        expect(output).to include("Run `hip validate` to verify changes")
      end

      it "includes reference documentation" do
        output = capture_stdout { described_class.new.execute }

        expect(output).to include("Reference Documentation")
        expect(output).to include("Schema & Examples")
      end
    end

    context "with --to option" do
      it "uses specified target version in migration guide" do
        # Fixture version is "2", so migrating to "9.0.0" should show guide
        output = capture_stdout { described_class.new(to: "9.0.0").execute }

        expect(output).to include("Migration Checklist")
        expect(output).to include("version: '2'")  # shows current version
        expect(output).to include("version: '9.0.0'")  # shows target version
      end
    end
  end

  describe "#version_compare" do
    subject { described_class.new }

    it "compares versions correctly" do
      expect(subject.send(:version_compare, "8.1.0", "9.2.0")).to eq(-1)
      expect(subject.send(:version_compare, "9.2.0", "8.1.0")).to eq(1)
      expect(subject.send(:version_compare, "9.2.0", "9.2.0")).to eq(0)
    end

    it "handles unknown versions" do
      expect(subject.send(:version_compare, "unknown", "9.2.0")).to eq(0)
      expect(subject.send(:version_compare, "9.2.0", "unknown")).to eq(0)
    end

    it "compares patch versions" do
      expect(subject.send(:version_compare, "9.1.3", "9.2.0")).to eq(-1)
      expect(subject.send(:version_compare, "9.2.1", "9.2.0")).to eq(1)
    end
  end

  describe "#analyze_config" do
    subject { described_class.new }

    it "returns analysis with config paths" do
      analysis = subject.send(:analyze_config)

      expect(analysis).to include(:issues)
      expect(analysis).to include(:new_features)
      expect(analysis).to include(:config_path)
      expect(analysis).to include(:schema_path)
      expect(analysis).to include(:examples_dir)
    end

    it "detects when no issues present" do
      analysis = subject.send(:analyze_config)

      # Current hip.yml doesn't have deprecated features
      deprecated_issues = analysis[:issues].select { |i| i[:type] == :deprecated }
      expect(deprecated_issues).to be_empty
    end
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
