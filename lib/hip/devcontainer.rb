# frozen_string_literal: true

require "json"
require "fileutils"
require "pathname"

module Hip
  # DevContainer integration module
  # Provides bidirectional sync between hip.yml and .devcontainer/devcontainer.json
  class DevContainer
    DEVCONTAINER_DIR = ".devcontainer"
    DEVCONTAINER_FILE = "devcontainer.json"
    DEFAULT_DEVCONTAINER_PATH = File.join(DEVCONTAINER_DIR, DEVCONTAINER_FILE)

    # Feature name shortcuts for common devcontainer features
    FEATURE_SHORTCUTS = {
      "docker-in-docker" => "ghcr.io/devcontainers/features/docker-in-docker:2",
      "docker" => "ghcr.io/devcontainers/features/docker-in-docker:2",
      "github-cli" => "ghcr.io/devcontainers/features/github-cli:1",
      "gh" => "ghcr.io/devcontainers/features/github-cli:1",
      "node" => "ghcr.io/devcontainers/features/node:1",
      "nodejs" => "ghcr.io/devcontainers/features/node:1",
      "python" => "ghcr.io/devcontainers/features/python:1",
      "go" => "ghcr.io/devcontainers/features/go:1",
      "rust" => "ghcr.io/devcontainers/features/rust:1",
      "git" => "ghcr.io/devcontainers/features/git:1",
      "git-lfs" => "ghcr.io/devcontainers/features/git-lfs:1",
      "aws-cli" => "ghcr.io/devcontainers/features/aws-cli:1",
      "azure-cli" => "ghcr.io/devcontainers/features/azure-cli:1",
      "kubectl" => "ghcr.io/devcontainers/features/kubectl-helm-minikube:1",
      "terraform" => "ghcr.io/devcontainers/features/terraform:1"
    }.freeze

    attr_reader :config, :devcontainer_path

    def initialize(config = Hip.config)
      @config = config
      @devcontainer_path = determine_devcontainer_path
    end

    # Generate .devcontainer/devcontainer.json from hip.yml configuration
    def generate
      Hip.logger.debug "DevContainer#generate: Generating devcontainer.json from hip.yml"

      devcontainer_config = build_devcontainer_config
      write_devcontainer_file(devcontainer_config)

      Hip.logger.info "Generated #{devcontainer_path}"
      devcontainer_path
    end

    # Read existing .devcontainer/devcontainer.json and return parsed content
    def read
      Hip.logger.debug "DevContainer#read: Reading #{devcontainer_path}"

      raise Hip::Error, "DevContainer file not found: #{devcontainer_path}" unless File.exist?(devcontainer_path)

      JSON.parse(File.read(devcontainer_path))
    end

    # Sync hip.yml devcontainer config to .devcontainer/devcontainer.json
    def sync_to_devcontainer
      Hip.logger.debug "DevContainer#sync_to_devcontainer: Syncing hip.yml → devcontainer.json"

      existing_config = File.exist?(devcontainer_path) ? read : {}
      new_config = build_devcontainer_config
      merged_config = existing_config.merge(new_config)

      write_devcontainer_file(merged_config)

      Hip.logger.info "Synced hip.yml → #{devcontainer_path}"
      devcontainer_path
    end

    # Sync .devcontainer/devcontainer.json to hip.yml devcontainer section
    def sync_from_devcontainer
      Hip.logger.debug "DevContainer#sync_from_devcontainer: Syncing devcontainer.json → hip.yml"

      devcontainer_config = read
      hip_config = build_hip_config_from_devcontainer(devcontainer_config)

      # Note: This returns the config hash but doesn't write to hip.yml
      # Actual writing should be done by a separate command
      hip_config
    end

    # Validate devcontainer.json exists and is valid JSON
    def validate
      Hip.logger.debug "DevContainer#validate: Validating #{devcontainer_path}"

      raise Hip::Error, "DevContainer file not found: #{devcontainer_path}" unless File.exist?(devcontainer_path)

      begin
        config = JSON.parse(File.read(devcontainer_path))
        Hip.logger.info "DevContainer configuration is valid"
        true
      rescue JSON::ParserError => e
        raise Hip::Error, "Invalid JSON in devcontainer.json: #{e.message}"
      end
    end

    # Check if devcontainer is enabled in hip.yml
    def enabled?
      return false unless config.to_h.key?(:devcontainer)

      dc_config = config.devcontainer
      dc_config.is_a?(Hash) && dc_config.fetch(:enabled, true)
    end

    # Get the service name to use for devcontainer
    def service_name
      if config.to_h.key?(:devcontainer)
        dc_config = config.devcontainer
        return dc_config[:service] if dc_config.is_a?(Hash) && dc_config[:service]
      end

      # Fallback: try to infer from compose config
      if config.compose.is_a?(Hash) && config.compose[:files]
        # Return first service from docker-compose.yml (simplified)
        "app"
      else
        "app"
      end
    end

    private

    def determine_devcontainer_path
      if config.to_h.key?(:devcontainer)
        dc_config = config.devcontainer
        if dc_config.is_a?(Hash) && dc_config[:config_path]
          return Pathname.new(dc_config[:config_path])
        end
      end

      Pathname.new(DEFAULT_DEVCONTAINER_PATH)
    end

    def build_devcontainer_config
      dc_config = config.to_h[:devcontainer] || {}

      devcontainer = {}

      # Basic configuration
      devcontainer["name"] = dc_config[:name] if dc_config[:name]

      # Docker configuration
      if dc_config[:image]
        devcontainer["image"] = dc_config[:image]
      elsif dc_config[:dockerFile]
        devcontainer["dockerFile"] = dc_config[:dockerFile]
      elsif config.compose.is_a?(Hash) && config.compose[:files]
        # Use docker-compose if configured
        devcontainer["dockerComposeFile"] = compose_files_for_devcontainer
        devcontainer["service"] = dc_config[:service] || service_name
      end

      # Workspace configuration
      devcontainer["workspaceFolder"] = dc_config[:workspaceFolder] if dc_config[:workspaceFolder]
      devcontainer["remoteUser"] = dc_config[:remoteUser] if dc_config[:remoteUser]

      # Features
      if dc_config[:features]
        devcontainer["features"] = expand_feature_shortcuts(dc_config[:features])
      end

      # Customizations
      devcontainer["customizations"] = dc_config[:customizations] if dc_config[:customizations]

      # Ports
      devcontainer["forwardPorts"] = dc_config[:forwardPorts] if dc_config[:forwardPorts]

      # Lifecycle commands
      devcontainer["postCreateCommand"] = dc_config[:postCreateCommand] if dc_config[:postCreateCommand]
      devcontainer["postStartCommand"] = dc_config[:postStartCommand] if dc_config[:postStartCommand]
      devcontainer["postAttachCommand"] = dc_config[:postAttachCommand] if dc_config[:postAttachCommand]

      # Advanced options
      devcontainer["mounts"] = dc_config[:mounts] if dc_config[:mounts]
      devcontainer["runArgs"] = dc_config[:runArgs] if dc_config[:runArgs]

      devcontainer
    end

    def build_hip_config_from_devcontainer(devcontainer_config)
      hip_dc_config = {}

      hip_dc_config[:enabled] = true
      hip_dc_config[:name] = devcontainer_config["name"] if devcontainer_config["name"]
      hip_dc_config[:image] = devcontainer_config["image"] if devcontainer_config["image"]
      hip_dc_config[:dockerFile] = devcontainer_config["dockerFile"] if devcontainer_config["dockerFile"]
      hip_dc_config[:service] = devcontainer_config["service"] if devcontainer_config["service"]
      hip_dc_config[:workspaceFolder] = devcontainer_config["workspaceFolder"] if devcontainer_config["workspaceFolder"]
      hip_dc_config[:remoteUser] = devcontainer_config["remoteUser"] if devcontainer_config["remoteUser"]
      hip_dc_config[:features] = devcontainer_config["features"] if devcontainer_config["features"]
      hip_dc_config[:customizations] = devcontainer_config["customizations"] if devcontainer_config["customizations"]
      hip_dc_config[:forwardPorts] = devcontainer_config["forwardPorts"] if devcontainer_config["forwardPorts"]
      hip_dc_config[:postCreateCommand] = devcontainer_config["postCreateCommand"] if devcontainer_config["postCreateCommand"]
      hip_dc_config[:postStartCommand] = devcontainer_config["postStartCommand"] if devcontainer_config["postStartCommand"]
      hip_dc_config[:postAttachCommand] = devcontainer_config["postAttachCommand"] if devcontainer_config["postAttachCommand"]
      hip_dc_config[:mounts] = devcontainer_config["mounts"] if devcontainer_config["mounts"]
      hip_dc_config[:runArgs] = devcontainer_config["runArgs"] if devcontainer_config["runArgs"]

      hip_dc_config
    end

    def compose_files_for_devcontainer
      compose_config = config.compose
      return ["docker-compose.yml"] unless compose_config.is_a?(Hash)

      files = compose_config[:files]
      return ["docker-compose.yml"] unless files.is_a?(Array)

      # Make paths relative to .devcontainer directory
      files.map { |f| "../#{f}" }
    end

    def expand_feature_shortcuts(features)
      return features unless features.is_a?(Hash)

      expanded = {}
      features.each do |name, options|
        name_str = name.to_s
        expanded_name = FEATURE_SHORTCUTS[name_str] || name
        expanded[expanded_name] = options || {}
      end
      expanded
    end

    def write_devcontainer_file(config_hash)
      FileUtils.mkdir_p(File.dirname(devcontainer_path))

      File.write(devcontainer_path, JSON.pretty_generate(config_hash))
    end
  end
end
