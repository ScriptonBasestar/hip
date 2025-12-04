# frozen_string_literal: true

require "shellwords"
require "hip/cli"
require "hip/commands/run"

describe Hip::Commands::Runners::DockerComposeRunner, :config do
  let(:config) { {interaction: commands} }
  let(:commands) do
    {
      bash: {service: "app"},
      bash_shell: {service: "app", command: "bash", shell: false},
      rails: {runner: "docker_compose", service: "app", command: "rails"},
      psql: {service: "postgres", command: "psql -h postgres", default_args: "db_dev"}
    }
  end
  let(:cli) { Hip::CLI }

  context "when run bash command" do
    before { cli.start "run bash".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--rm", "app"]) }
  end

  context "when the command has shell: false option" do
    before { cli.start "run bash_shell pwd".shellsplit }

    it do
      expect(exec_program_runner).to have_received(:call).with(["docker", "compose", "run", "--rm", "app", "bash", "pwd"], kind_of(Hash))
    end
  end

  context "when run shorthanded bash command" do
    before { cli.start ["bash"] }

    it { expected_exec("docker", ["compose", "run", "--rm", "app"]) }
  end

  context "when publish ports" do
    before { cli.start "run --publish 3:3 -p 5:5 rails s".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--publish=3:3", "--publish=5:5", "--rm", "app", "rails", "s"]) }
  end

  context "when publish is part of a command" do
    before { cli.start "run rails s --publish=3000:3000".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--rm", "app", "rails", "s", "--publish\\=3000:3000"]) }
  end

  context "when run psql command without db name" do
    before { cli.start "run psql".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--rm", "postgres", "psql", "-h", "postgres", "db_dev"]) }
  end

  context "when run psql command with db name" do
    before { cli.start "run psql db_test".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--rm", "postgres", "psql", "-h", "postgres", "db_test"]) }
  end

  context "when run rails command" do
    before { cli.start "run rails".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--rm", "app", "rails"]) }
  end

  context "when run rails command with subcommand" do
    before { cli.start "run rails console".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--rm", "app", "rails", "console"]) }
  end

  context "when run rails command with arguments" do
    before { cli.start "run rails g migration add_index --force".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--rm", "app", "rails", "g", "migration", "add_index", "--force"]) }
  end

  # backward compatibility
  context "when config with compose_run_options" do
    let(:commands) { {bash: {service: "app", compose_run_options: ["foo", "-bar", "--baz=qux"]}} }

    before { cli.start "run bash".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--foo", "-bar", "--baz=qux", "--rm", "app"]) }
  end

  context "when config with compose: run_options" do
    let(:commands) { {bash: {service: "app", compose: {run_options: ["foo", "-bar", "--baz=qux"]}}} }

    before { cli.start "run bash".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--foo", "-bar", "--baz=qux", "--rm", "app"]) }
  end

  # backward compatibility
  context "when config with compose_method" do
    let(:commands) { {rails: {service: "app", command: "rails", compose_method: "up"}} }

    before { cli.start "run rails server".shellsplit }

    it { expected_exec("docker", ["compose", "up", "app", "rails", "server"]) }
  end

  context "when config with compose: method" do
    let(:commands) { {rails: {service: "app", command: "rails", compose: {method: "up"}}} }

    before { cli.start "run rails server".shellsplit }

    it { expected_exec("docker", ["compose", "up", "app", "rails", "server"]) }
  end

  context "when run vars" do
    context "when execute through `compose run`" do
      before { cli.start "FOO=foo run bash".shellsplit }

      it { expected_exec("docker", ["compose", "run", "-e", "FOO=foo", "--rm", "app"]) }
    end

    context "when execute through `compose up`" do
      let(:commands) { {rails: {service: "app", command: "rails", compose_method: "up"}} }

      before { cli.start "FOO=foo run rails server".shellsplit }

      it { expected_exec("docker", ["compose", "up", "app", "rails", "server"]) }
    end
  end

  context "when config with environment vars" do
    let(:commands) { {rspec: {service: "app", command: "rspec", environment: {"RAILS_ENV" => "test"}}} }

    before { cli.start "run rspec".shellsplit }

    it { expected_exec("docker", ["compose", "run", "--rm", "app", "rspec"], env: hash_including("RAILS_ENV" => "test")) }
  end

  context "when config with profiles" do
    let(:commands) do
      {
        stack: {
          runner: "docker_compose",
          compose_run_options: ["foo", "-bar", "--baz=qux"],
          compose: {profiles: ["foo", "bar"]}
        }
      }
    end

    before { cli.start "run stack".shellsplit }

    it { expected_exec("docker", ["compose", "--profile", "foo", "--profile", "bar", "up"]) }
  end

  context "when config with subcommands" do
    let(:commands) { {rails: {service: "app", command: "rails", subcommands: subcommands}} }
    let(:subcommands) { {s: {command: "rails server"}} }

    context "and run rails server" do
      before { cli.start "run rails s".shellsplit }

      it { expected_exec("docker", ["compose", "run", "--rm", "app", "rails", "server"]) }
    end

    context "when run rails command with other subcommand" do
      before { cli.start "run rails console".shellsplit }

      it { expected_exec("docker", ["compose", "run", "--rm", "app", "rails", "console"]) }
    end

    context "when run rails command with arguments" do
      before { cli.start "run rails s foo --bar".shellsplit }

      it { expected_exec("docker", ["compose", "run", "--rm", "app", "rails", "server", "foo", "--bar"]) }
    end

    context "when config with compose_run_options" do
      let(:subcommands) { {s: {command: "rails s", compose_run_options: ["foo", "-bar", "--baz=qux"]}} }

      before { cli.start "run rails s".shellsplit }

      it { expected_exec("docker", ["compose", "run", "--foo", "-bar", "--baz=qux", "--rm", "app", "rails", "s"]) }
    end

    context "when config with compose_method" do
      let(:subcommands) { {s: {service: "web", compose_method: "up"}} }

      before { cli.start "run rails s".shellsplit }

      it { expected_exec("docker", ["compose", "up", "web"]) }
    end

    context "when config with environment vars" do
      let(:subcommands) do
        {"refresh-test-db": {command: "rake db:drop db:tests:prepare db:migrate",
                             environment: {"RAILS_ENV" => "test"}}}
      end

      before { cli.start "run rails refresh-test-db".shellsplit }

      it do
        expected_exec("docker",
          ["compose", "run", "--rm", "app", "rake", "db:drop", "db:tests:prepare", "db:migrate"],
          env: hash_including("RAILS_ENV" => "test"))
      end
    end

    context "when config with profiles" do
      let(:subcommands) do
        {
          all: {
            compose_run_options: ["foo", "-bar", "--baz=qux"],
            compose: {profiles: ["foo", "bar"]}
          }
        }
      end

      before { cli.start "run rails all".shellsplit }

      it { expected_exec("docker", ["compose", "--profile", "foo", "--profile", "bar", "up", "app"]) }
    end
  end

  context "when container is already running" do
    let(:commands) { {bash: {service: "app", command: "bash"}} }
    let(:runner) { described_class.new(command, [], **{}) }
    let(:command) do
      {
        service: "app",
        command: "bash",
        shell: true,
        compose: {method: "run", run_options: [], profiles: []},
        environment: {}
      }
    end

    before do
      allow(Hip::ContainerUtils).to receive(:service_running_project).with("app").and_return("test-project")
    end

    it "switches from run to exec" do
      runner.send(:auto_detect_compose_method!)
      expect(command[:compose][:method]).to eq("exec")
    end
  end

  context "when container is not running" do
    let(:commands) { {bash: {service: "app", command: "bash"}} }
    let(:runner) { described_class.new(command, [], **{}) }
    let(:command) do
      {
        service: "app",
        command: "bash",
        shell: true,
        compose: {method: "run", run_options: [], profiles: []},
        environment: {}
      }
    end

    before do
      allow(Hip::ContainerUtils).to receive(:service_running_project).with("app").and_return(nil)
    end

    it "keeps run method" do
      runner.send(:auto_detect_compose_method!)
      expect(command[:compose][:method]).to eq("run")
    end
  end

  context "when method is already exec" do
    let(:commands) { {bash: {service: "app", command: "bash", compose: {method: "exec"}}} }
    let(:runner) { described_class.new(command, [], **{}) }
    let(:command) do
      {
        service: "app",
        command: "bash",
        shell: true,
        compose: {method: "exec", run_options: [], profiles: []},
        environment: {}
      }
    end

    it "does not check container status" do
      expect(Hip::ContainerUtils).not_to receive(:service_running_project)
      runner.send(:auto_detect_compose_method!)
      expect(command[:compose][:method]).to eq("exec")
    end
  end
end
