# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "env_file integration" do
  let(:tmpdir) { Dir.mktmpdir }
  let(:project_dir) { Pathname.new(tmpdir) }
  let(:hip_yml_path) { project_dir.join("hip.yml") }

  around do |example|
    original_dir = Dir.pwd
    original_hip_file = ENV["HIP_FILE"]

    FileUtils.mkdir_p(project_dir)
    Dir.chdir(project_dir)
    ENV["HIP_FILE"] = hip_yml_path.to_s

    example.run
  ensure
    Dir.chdir(original_dir)
    ENV["HIP_FILE"] = original_hip_file
    FileUtils.rm_rf(tmpdir) if tmpdir && File.exist?(tmpdir)
    Hip.reset!
  end

  describe "top-level env_file" do
    context "with simple env_file configuration" do
      let(:hip_yml) do
        <<~YAML
          version: '#{Hip::VERSION}'
          env_file: .env
          environment:
            RAILS_ENV: development
        YAML
      end

      before do
        File.write(hip_yml_path, hip_yml)
        File.write(project_dir.join(".env"), <<~ENV)
          DATABASE_PASSWORD=secret123
          SECRET_KEY_BASE=abcd1234
        ENV
      end

      it "loads env_file variables into Hip.env" do
        Hip.reset!
        expect(Hip.env["DATABASE_PASSWORD"]).to eq("secret123")
        expect(Hip.env["SECRET_KEY_BASE"]).to eq("abcd1234")
        expect(Hip.env["RAILS_ENV"]).to eq("development")
      end
    end

    context "with priority: before_environment" do
      let(:hip_yml) do
        <<~YAML
          version: '#{Hip::VERSION}'
          env_file:
            files: .env
            priority: before_environment
          environment:
            LOG_LEVEL: info
            DATABASE_HOST: postgres
        YAML
      end

      before do
        File.write(hip_yml_path, hip_yml)
        File.write(project_dir.join(".env"), <<~ENV)
          LOG_LEVEL=debug
          DATABASE_PASSWORD=secret
        ENV
      end

      it "allows environment: to override env_file" do
        Hip.reset!
        expect(Hip.env["LOG_LEVEL"]).to eq("info") # From environment:
        expect(Hip.env["DATABASE_PASSWORD"]).to eq("secret") # From .env
        expect(Hip.env["DATABASE_HOST"]).to eq("postgres") # From environment:
      end
    end

    context "with priority: after_environment" do
      let(:hip_yml) do
        <<~YAML
          version: '#{Hip::VERSION}'
          env_file:
            files: .env
            priority: after_environment
          environment:
            LOG_LEVEL: info
            DATABASE_HOST: postgres
        YAML
      end

      before do
        File.write(hip_yml_path, hip_yml)
        File.write(project_dir.join(".env"), <<~ENV)
          LOG_LEVEL=debug
          DATABASE_PASSWORD=secret
        ENV
      end

      it "allows env_file to override environment:" do
        Hip.reset!
        expect(Hip.env["LOG_LEVEL"]).to eq("debug") # From .env (overrides environment:)
        expect(Hip.env["DATABASE_PASSWORD"]).to eq("secret") # From .env
        expect(Hip.env["DATABASE_HOST"]).to eq("postgres") # From environment: (not in .env)
      end
    end

    context "with multiple env files" do
      let(:hip_yml) do
        <<~YAML
          version: '#{Hip::VERSION}'
          env_file:
            - .env.defaults
            - .env
            - .env.local
        YAML
      end

      before do
        File.write(hip_yml_path, hip_yml)
        File.write(project_dir.join(".env.defaults"), "BASE=1\nLOG_LEVEL=warn")
        File.write(project_dir.join(".env"), "BASE=2\nSECRET=secret123")
        File.write(project_dir.join(".env.local"), "LOG_LEVEL=debug")
      end

      it "merges files in order with later files overriding" do
        Hip.reset!
        expect(Hip.env["BASE"]).to eq("2")
        expect(Hip.env["LOG_LEVEL"]).to eq("debug")
        expect(Hip.env["SECRET"]).to eq("secret123")
      end
    end

    context "with required files" do
      let(:hip_yml) do
        <<~YAML
          version: '#{Hip::VERSION}'
          env_file:
            - path: .env.required
              required: true
            - path: .env.optional
              required: false
        YAML
      end

      context "when required file is missing" do
        before do
          File.write(hip_yml_path, hip_yml)
          # Don't create .env.required
        end

        it "raises error" do
          Hip.reset!
          expect { Hip.env["REQUIRED_KEY"] }.to raise_error(Hip::Error, /Required environment file not found/)
        end
      end

      context "when required file exists" do
        before do
          File.write(hip_yml_path, hip_yml)
          File.write(project_dir.join(".env.required"), "REQUIRED_KEY=value")
          # Don't create .env.optional
        end

        it "loads successfully" do
          Hip.reset!
          expect(Hip.env["REQUIRED_KEY"]).to eq("value")
        end
      end
    end
  end

  describe "interaction-level env_file" do
    let(:hip_yml) do
      <<~YAML
        version: '#{Hip::VERSION}'
        env_file: .env
        environment:
          RAILS_ENV: development
        compose:
          files:
            - docker-compose.yml
        interaction:
          rails:
            service: web
            command: bundle exec rails
          rspec:
            service: web
            command: bundle exec rspec
            env_file: .env.test
            environment:
              RAILS_ENV: test
      YAML
    end

    let(:compose_yml) do
      <<~YAML
        services:
          web:
            image: ruby:3.3
      YAML
    end

    before do
      File.write(hip_yml_path, hip_yml)
      File.write(project_dir.join("docker-compose.yml"), compose_yml)
      File.write(project_dir.join(".env"), "DATABASE_NAME=myapp_dev")
      File.write(project_dir.join(".env.test"), "DATABASE_NAME=myapp_test\nRAILS_LOG_LEVEL=error")
    end

    it "loads top-level env_file for rails command" do
      Hip.reset!

      # Simulate running "hip rails console"
      require "hip/commands/run"
      Hip::Commands::Run.new("rails", "console", explain: true)

      expect(Hip.env["DATABASE_NAME"]).to eq("myapp_dev")
      expect(Hip.env["RAILS_ENV"]).to eq("development")
    end

    it "loads interaction-level env_file for rspec command" do
      Hip.reset!

      # Simulate running "hip rspec"
      require "hip/commands/run"
      Hip::Commands::Run.new("rspec", explain: true)

      expect(Hip.env["DATABASE_NAME"]).to eq("myapp_test") # From .env.test
      expect(Hip.env["RAILS_LOG_LEVEL"]).to eq("error") # From .env.test
      expect(Hip.env["RAILS_ENV"]).to eq("test") # From interaction environment:
    end
  end

  describe "variable interpolation" do
    let(:hip_yml) do
      <<~YAML
        version: '#{Hip::VERSION}'
        env_file: .env
        environment:
          APP_NAME: myapp
      YAML
    end

    before do
      File.write(hip_yml_path, hip_yml)
      File.write(project_dir.join(".env"), <<~ENV)
        DATABASE_HOST=localhost
        DATABASE_PORT=5432
        DATABASE_USER=postgres
        DATABASE_NAME=myapp_dev
        DATABASE_URL=postgres://${DATABASE_USER}@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}
      ENV
    end

    it "interpolates variables in env_file" do
      Hip.reset!
      expect(Hip.env["DATABASE_URL"]).to eq("postgres://postgres@localhost:5432/myapp_dev")
    end
  end

  describe "system ENV override" do
    let(:hip_yml) do
      <<~YAML
        version: '#{Hip::VERSION}'
        env_file: .env
        environment:
          LOG_LEVEL: info
      YAML
    end

    before do
      File.write(hip_yml_path, hip_yml)
      File.write(project_dir.join(".env"), "LOG_LEVEL=debug")
      ENV["LOG_LEVEL"] = "trace"
    end

    after do
      ENV.delete("LOG_LEVEL")
    end

    it "system ENV overrides everything" do
      Hip.reset!
      expect(Hip.env["LOG_LEVEL"]).to eq("trace")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
