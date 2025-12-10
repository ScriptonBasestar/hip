# frozen_string_literal: true

require "spec_helper"
require "hip/commands/migrate"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "Hip Migration Integration", type: :integration do
  describe "deprecated v8 configuration", :env do
    let(:env) { {"HIP_FILE" => fixture_path("deprecated-v8", "hip.yml")} }

    it "detects all deprecated features" do
      migrate = Hip::Commands::Migrate.new
      analysis = migrate.send(:analyze_config)

      # Should find deprecated compose_run_options
      deprecated_issues = analysis[:issues].select { |i| i[:type] == :deprecated }
      expect(deprecated_issues.size).to eq(2), "Expected 2 deprecated features (rails, npm)"

      rails_issue = deprecated_issues.find { |i| i[:location] == "interaction.rails" }
      expect(rails_issue).not_to be_nil
      expect(rails_issue[:feature]).to eq("compose_run_options")
      expect(rails_issue[:current]).to eq(["service-ports", "rm"])

      npm_issue = deprecated_issues.find { |i| i[:location] == "interaction.npm" }
      expect(npm_issue).not_to be_nil
      expect(npm_issue[:current]).to eq(["rm"])
    end

    it "detects legacy provision format" do
      migrate = Hip::Commands::Migrate.new
      analysis = migrate.send(:analyze_config)

      legacy_issues = analysis[:issues].select { |i| i[:type] == :legacy_format }
      expect(legacy_issues.size).to eq(2), "Expected 2 provision profiles with legacy format"

      default_issue = legacy_issues.find { |i| i[:location] == "provision.default" }
      expect(default_issue).not_to be_nil
      expect(default_issue[:legacy_count]).to eq(4)  # 4 echo commands
      expect(default_issue[:total_steps]).to eq(8)   # 8 total steps

      reset_issue = legacy_issues.find { |i| i[:location] == "provision.reset" }
      expect(reset_issue).not_to be_nil
      expect(reset_issue[:legacy_count]).to eq(3)
    end

    it "generates complete migration guide" do
      output = capture_stdout { Hip::Commands::Migrate.new.execute }

      # Should include all sections
      expect(output).to include("Hip Configuration Migration Guide")
      expect(output).to include("Current Version**: 8.1.0")
      expect(output).to include("Latest Version**: #{Hip::VERSION}")
      expect(output).to include("Migration Required**: YES")

      # Breaking changes section
      expect(output).to include("Breaking Changes & Deprecations")
      expect(output).to include("compose_run_options (Deprecated)")
      expect(output).to include("interaction.rails")
      expect(output).to include("interaction.npm")

      # Legacy provision section
      expect(output).to include("Provision Legacy Format")
      expect(output).to include("provision.default")
      expect(output).to include("provision.reset")
      expect(output).to include("step/run/note syntax")

      # Migration checklist
      expect(output).to include("Migration Checklist")
      expect(output).to include("version: '8.1.0'")
      expect(output).to include("version: '#{Hip::VERSION}'")
    end

    it "recommends env_file feature" do
      output = capture_stdout { Hip::Commands::Migrate.new.execute }

      expect(output).to include("New Features Available")
      expect(output).to include("env_file Support")
      expect(output).to include("env_file: .env")
    end
  end

  describe "migrated v9 configuration", :env do
    let(:env) { {"HIP_FILE" => fixture_path("migrated-v9", "hip.yml")} }

    it "detects no deprecated features" do
      migrate = Hip::Commands::Migrate.new
      analysis = migrate.send(:analyze_config)

      deprecated_issues = analysis[:issues].select { |i| i[:type] == :deprecated }
      expect(deprecated_issues).to be_empty, "Should not find any deprecated features"
    end

    it "detects no legacy provision format" do
      migrate = Hip::Commands::Migrate.new
      analysis = migrate.send(:analyze_config)

      legacy_issues = analysis[:issues].select { |i| i[:type] == :legacy_format }
      expect(legacy_issues).to be_empty, "Should not find any legacy provision format"
    end

    it "shows up-to-date message" do
      output = capture_stdout { Hip::Commands::Migrate.new.execute }

      expect(output).to include("✅ Your hip.yml is already at version 9.2.1")
    end
  end

  describe "version comparison edge cases" do
    it "handles patch version differences" do
      migrate = Hip::Commands::Migrate.new

      expect(migrate.send(:version_compare, "9.1.0", "9.1.3")).to eq(-1)
      expect(migrate.send(:version_compare, "9.1.3", "9.1.0")).to eq(1)
      expect(migrate.send(:version_compare, "9.1.3", "9.1.3")).to eq(0)
    end

    it "handles major version differences" do
      migrate = Hip::Commands::Migrate.new

      expect(migrate.send(:version_compare, "8.0.0", "9.0.0")).to eq(-1)
      expect(migrate.send(:version_compare, "9.0.0", "8.0.0")).to eq(1)
    end

    it "handles unknown versions gracefully" do
      migrate = Hip::Commands::Migrate.new

      expect(migrate.send(:version_compare, "unknown", "9.2.0")).to eq(0)
      expect(migrate.send(:version_compare, "9.2.0", "unknown")).to eq(0)
    end
  end

  describe "target version option" do
    let(:env) { {"HIP_FILE" => fixture_path("deprecated-v8", "hip.yml")} }

    it "uses custom target version", :env do
      output = capture_stdout { Hip::Commands::Migrate.new(to: "9.0.0").execute }

      expect(output).to include("version: '8.1.0'")
      expect(output).to include("version: '9.0.0'")
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
# rubocop:enable RSpec/DescribeClass
