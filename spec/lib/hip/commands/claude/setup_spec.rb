# frozen_string_literal: true

require "hip/commands/claude/setup"

describe Hip::Commands::Claude::Setup do
  subject { described_class.new(options) }

  let(:options) { {} }
  let(:config) do
    {
      version: "8",
      interaction: {
        console: {
          description: "Open Rails console",
          service: "rails",
          command: "bin/rails console"
        },
        test: {
          description: "Run test suite",
          service: "rails",
          command: "bundle exec rspec"
        }
      },
      environment: {
        RAILS_ENV: "development",
        DATABASE_URL: "postgres://db:5432/myapp"
      }
    }
  end

  before do
    allow(Hip.config).to receive_messages(exist?: true, interaction: config[:interaction], environment: config[:environment], compose: nil)
    allow(Dir).to receive(:pwd).and_return("/test/project")
  end

  describe "#execute" do
    context "when hip.yml exists" do
      it "creates .claude directory structure" do
        expect(FileUtils).to receive(:mkdir_p).with(".claude/ctx")
        expect(FileUtils).to receive(:mkdir_p).with(".claude/commands")

        expect(File).to receive(:write).with(
          ".claude/ctx/hip-project-guide.md",
          anything
        )
        expect(File).to receive(:write).with(
          ".claude/commands/hip.md",
          anything
        )

        subject.execute
      end

      it "generates project guide with commands list" do
        guide_content = nil
        allow(File).to receive(:write) do |path, content|
          guide_content = content if path == ".claude/ctx/hip-project-guide.md"
        end
        allow(FileUtils).to receive(:mkdir_p)

        subject.execute

        expect(guide_content).to include("# Hip Commands: project")
        expect(guide_content).to include("| Command | Description |")
        expect(guide_content).to include("| hip console | Open Rails console |")
        expect(guide_content).to include("| hip test | Run test suite |")
      end

      it "generates slash command file" do
        slash_content = nil
        allow(File).to receive(:write) do |path, content|
          slash_content = content if path == ".claude/commands/hip.md"
        end
        allow(FileUtils).to receive(:mkdir_p)

        subject.execute

        expect(slash_content).to include("# Hip Command Helper")
        expect(slash_content).to include("/hip")
      end
    end

    context "with --global option" do
      let(:options) { {global: true} }

      it "creates global reference guide" do
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)

        expect(FileUtils).to receive(:mkdir_p).with(
          File.dirname(File.expand_path("~/.claude/ctx/HIP_QUICK_REFERENCE.md"))
        )
        expect(File).to receive(:write).with(
          File.expand_path("~/.claude/ctx/HIP_QUICK_REFERENCE.md"),
          anything
        )

        subject.execute
      end

      it "includes Hip version in global guide" do
        global_content = nil
        allow(File).to receive(:write) do |path, content|
          if path == File.expand_path("~/.claude/ctx/HIP_QUICK_REFERENCE.md")
            global_content = content
          end
        end
        allow(FileUtils).to receive(:mkdir_p)

        subject.execute

        expect(global_content).to include("# Hip Quick Reference")
        expect(global_content).to include("hip claude:setup")
        expect(global_content).to include("## Commands")
      end
    end

    context "when hip.yml does not exist" do
      before do
        allow(Hip.config).to receive(:exist?).and_return(false)
      end

      it "raises an error" do
        expect { subject.execute }.to raise_error(
          Hip::Error,
          /No hip\.yml found/
        )
      end
    end
  end

  describe "generated content formatting" do
    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
    end

    it "includes environment variables in project guide" do
      guide_content = nil
      allow(File).to receive(:write) do |path, content|
        guide_content = content if path == ".claude/ctx/hip-project-guide.md"
      end

      subject.execute

      expect(guide_content).to include("RAILS_ENV")
      expect(guide_content).to include("DATABASE_URL")
    end

    it "formats commands as markdown table" do
      guide_content = nil
      allow(File).to receive(:write) do |path, content|
        guide_content = content if path == ".claude/ctx/hip-project-guide.md"
      end

      subject.execute

      expect(guide_content).to include("| Command | Description |")
      expect(guide_content).to include("| hip console | Open Rails console |")
      expect(guide_content).to include("| hip test | Run test suite |")
    end

    it "omits empty sections" do
      guide_content = nil
      allow(File).to receive(:write) do |path, content|
        guide_content = content if path == ".claude/ctx/hip-project-guide.md"
      end
      allow(Hip.config).to receive_messages(compose: nil, environment: {})

      subject.execute

      expect(guide_content).not_to include("Services")
      expect(guide_content).not_to include("Environment")
    end
  end
end
