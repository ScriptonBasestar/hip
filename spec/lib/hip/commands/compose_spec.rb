# frozen_string_literal: true

require "shellwords"
require "hip/cli"
require "hip/commands/compose"

describe Hip::Commands::Compose do
  let(:cli) { Hip::CLI }

  context "when execute without extra arguments" do
    before { cli.start "compose run".shellsplit }

    it { expected_exec("docker", "compose run") }
  end

  context "hip up command" do
    context "when execute without arguments" do
      before { cli.start "up".shellsplit }

      it "adds default -d --wait options" do
        expected_exec("docker", ["compose", "up", "-d", "--wait"])
      end
    end

    context "when execute with --foreground flag" do
      before { cli.start "up --foreground".shellsplit }

      it "runs without -d --wait" do
        expected_exec("docker", ["compose", "up"])
      end
    end

    context "when execute with service name" do
      before { cli.start "up web".shellsplit }

      it "adds default options before service name" do
        expected_exec("docker", ["compose", "up", "-d", "--wait", "web"])
      end
    end

    context "when config contains custom up_options", :config do
      let(:config) { {compose: {up_options: ["--build", "-d"]}} }

      before { cli.start "up".shellsplit }

      it "uses custom up_options instead of defaults" do
        expected_exec("docker", ["compose", "up", "--build", "-d"])
      end
    end

    context "when -d is already in arguments" do
      before { cli.start "up -d".shellsplit }

      it "does not duplicate -d option but adds --wait" do
        expected_exec("docker", ["compose", "up", "--wait", "-d"])
      end
    end
  end

  context "when execute with arguments" do
    before { cli.start "compose run --rm bash".shellsplit }

    it { expected_exec("docker", ["compose run", "--rm", "bash"]) }
  end

  context "when config contains project_name", :config do
    let(:config) { {compose: {project_name: "rocket"}} }

    before { cli.start "compose run".shellsplit }

    it { expected_exec("docker", ["compose --project-name", "rocket", "run"]) }
  end

  context "when config contains project_name with env vars", :config, :env do
    let(:config) { {compose: {project_name: "rocket-$RAILS_ENV"}} }
    let(:env) { {"RAILS_ENV" => "test"} }

    before { cli.start "compose run".shellsplit }

    it { expected_exec("docker", ["compose --project-name", "rocket-test", "run"]) }
  end

  context "when config contains project_directory", :config do
    let(:config) { {compose: {project_directory: "/foo/bar"}} }

    before { cli.start "compose run".shellsplit }

    it { expected_exec("docker", ["compose --project-directory", "/foo/bar", "run"]) }
  end

  context "when config contains project_directory with env vars", :config, :env do
    let(:config) { {compose: {project_directory: "/foo-$RAILS_ENV"}} }
    let(:env) { {"RAILS_ENV" => "test"} }

    before { cli.start "compose run".shellsplit }

    it { expected_exec("docker", ["compose --project-directory", "/foo-test", "run"]) }
  end

  context "when compose's config path contains spaces", :config do
    let(:config) { {compose: {files: ["file name.yml"]}} }
    let(:file) { fixture_path("empty", "file name.yml") }

    before do
      allow_any_instance_of(Pathname).to receive(:exist?) do |obj|
        case obj.to_s
        when file
          true
        else
          File.exist?(obj.to_s)
        end
      end

      cli.start "compose run".shellsplit
    end

    it { expected_exec("docker", ["compose --file", Shellwords.escape(file), "run"]) }
  end

  context "when config contains multiple docker-compose files", :config do
    context "and some files are not exist" do
      let(:config) { {compose: {files: %w[file1.yml file2.yml file3.yml]}} }
      let(:global_file) { fixture_path("empty", "file1.yml") }
      let(:local_file) { fixture_path("empty", "file2.yml") }
      let(:override_file) { fixture_path("empty", "file3.yml") }

      before do
        allow_any_instance_of(Pathname).to receive(:exist?) do |obj|
          case obj.to_s
          when global_file, override_file
            true
          when local_file
            false
          else
            File.exist?(obj.to_s)
          end
        end

        cli.start "compose run".shellsplit
      end

      it { expected_exec("docker", ["compose --file", global_file, "--file", override_file, "run"]) }
    end

    context "and a file name contains env var", :env do
      let(:config) { {compose: {files: %w[file1-${HIP_OS}.yml]}} }
      let(:file) { fixture_path("empty", "file1-darwin.yml") }
      let(:env) { {"HIP_OS" => "darwin"} }

      before do
        allow_any_instance_of(Pathname).to receive(:exist?) do |obj|
          case obj.to_s
          when file
            true
          else
            File.exist?(obj.to_s)
          end
        end

        cli.start "compose run".shellsplit
      end

      it { expected_exec("docker", ["compose --file", file, "run"]) }
    end
  end

  context "when compose command specified in config", :config do
    context "when compose command contains spaces" do
      let(:config) { {compose: {command: "foo compose"}} }

      before { cli.start "compose run".shellsplit }

      it { expected_exec("foo compose", "run") }
    end

    context "when compose command does not contain spaces" do
      let(:config) { {compose: {command: "foo-compose"}} }

      before { cli.start "compose run".shellsplit }

      it { expected_exec("foo-compose", "run") }
    end
  end

  context "when HIP_COMPOSE_COMMAND is specified in environment", :env do
    context "when HIP_COMPOSE_COMMAND contains spaces" do
      let(:env) { {"HIP_COMPOSE_COMMAND" => "foo compose"} }

      before { cli.start "compose run".shellsplit }

      it { expected_exec("foo compose", "run") }
    end

    context "when HIP_COMPOSE_COMMAND does not contain spaces" do
      let(:env) { {"HIP_COMPOSE_COMMAND" => "foo-compose"} }

      before { cli.start "compose run".shellsplit }

      it { expected_exec("foo-compose", "run") }
    end

    context "when compose command specified in config", :config do
      let(:config) { {compose: {command: "foo compose"}} }
      let(:env) { {"HIP_COMPOSE_COMMAND" => "bar-compose"} }

      before { cli.start "compose run".shellsplit }

      it { expected_exec("bar-compose", "run") }
    end
  end

  describe "#build_command" do
    context "with basic arguments" do
      let(:compose) { described_class.new("ps", "--format", "json") }

      it "returns full docker compose command array" do
        expect(compose.build_command).to start_with("docker", "compose")
        expect(compose.build_command).to include("ps", "--format", "json")
      end
    end

    context "with config containing files and project_name", :config do
      let(:config) { {compose: {files: ["docker-compose.yml"], project_name: "test-project"}} }
      let(:compose) { described_class.new("ps") }
      let(:compose_file) { fixture_path("empty", "docker-compose.yml") }

      before do
        allow_any_instance_of(Pathname).to receive(:exist?) do |obj|
          obj.to_s == compose_file || File.exist?(obj.to_s)
        end
      end

      it "includes file arguments" do
        expect(compose.build_command).to include("--file")
      end

      it "includes project name" do
        expect(compose.build_command).to include("--project-name", "test-project")
      end
    end
  end

  describe "subprocess option" do
    context "when subprocess: false (default)" do
      let(:compose) { described_class.new("ps") }

      it "uses exec_program" do
        expect(Hip::Command).to receive(:exec_program)
        compose.execute
      end
    end

    context "when subprocess: true" do
      let(:compose) { described_class.new("ps", subprocess: true) }

      before do
        allow(Hip::Command).to receive(:exec_subprocess).and_return(true)
      end

      it "uses exec_subprocess" do
        expect(Hip::Command).to receive(:exec_subprocess)
        compose.execute
      end
    end
  end
end
