# frozen_string_literal: true

require "shellwords"
require "hip/cli/infra"
require "hip/commands/infra"

describe Hip::Commands::Infra, :config do
  let(:cli) { Hip::CLI::Infra }
  let(:config) { {infra: {nginx: {git: "some@git.repo"}}} }

  describe Hip::Commands::Infra::Update do
    let(:folder) { "#{Dip.home_path}/infra/nginx/latest" }

    it "creates folder and clones repo" do
      FakeFS do
        cli.start "update".shellsplit
        expect(Dir.exist?(folder)).to be true
      end

      expected_subprocess("git", "clone --single-branch --depth 1 --branch latest some@git.repo #{folder}")
    end

    context "when folder is exist" do
      it "just checkouts repo" do
        FakeFS do
          FileUtils.mkdir_p(folder)
          cli.start "update".shellsplit
        end

        expected_subprocess("git", "checkout .")
        expected_subprocess("git", "pull --rebase")
      end
    end

    describe Hip::Commands::Infra::Up do
      it "updates and runs infra services" do
        FakeFS do
          FileUtils.mkdir_p(folder)
          expect_any_instance_of(Hip::Commands::Infra::Update).to receive(:execute)
          cli.start "up --some-compose-arg".shellsplit
          expected_subprocess("docker", "network create dip-net-nginx-latest")
          expected_subprocess("docker", "compose up --detach --some-compose-arg")
        end
      end
    end

    describe Hip::Commands::Infra::Down do
      it "stops infra services" do
        FakeFS do
          FileUtils.mkdir_p(folder)
          expect_any_instance_of(Hip::Commands::Infra::Update).not_to receive(:execute)
          cli.start "down --some-compose-arg".shellsplit
          expected_subprocess("docker", "compose down --some-compose-arg")
        end
      end
    end
  end
end
