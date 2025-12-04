# frozen_string_literal: true

# @file: lib/hip/compose_file_parser.rb
# @purpose: Parse docker-compose files to extract service configurations
# @flow: ContainerUtils -> ComposeFileParser -> parsed service data
# @dependencies: yaml, pathname, hip/environment
# @key_methods: services_with_container_name

require "yaml"
require "pathname"

module Hip
  # Parses docker-compose files to extract configuration details
  # Used primarily for detecting container_name usage which conflicts
  # with Hip's auto-detection and project_name features
  #
  # @example Get services with explicit container_name
  #   parser = ComposeFileParser.new(Hip.config.compose)
  #   parser.services_with_container_name
  #   # => { "postgres" => "gorisa_postgres", "redis" => "gorisa_redis" }
  class ComposeFileParser
    attr_reader :compose_files

    # @param compose_config [Hash] The compose configuration from hip.yml
    def initialize(compose_config)
      @compose_config = compose_config || {}
      @compose_files = resolve_compose_files
      @parsed_services = nil
    end

    # Parse all compose files and return merged services hash
    # Later files override earlier ones (standard docker-compose behavior)
    #
    # @return [Hash] Merged services configuration
    def services
      @parsed_services ||= parse_all_files
    end

    # Get services that have explicit container_name set
    #
    # @return [Hash<String, String>] Map of service_name => container_name
    def services_with_container_name
      services.each_with_object({}) do |(name, config), result|
        if config.is_a?(Hash) && (container_name = config["container_name"])
          result[name] = container_name
        end
      end
    end

    # Check if any service has container_name defined
    #
    # @return [Boolean] true if at least one service has container_name
    def has_container_names?
      services_with_container_name.any?
    end

    private

    # Resolve compose file paths from configuration
    # Uses the same logic as Commands::Compose#find_files
    #
    # @return [Array<Pathname>] List of existing compose file paths
    def resolve_compose_files
      files = @compose_config[:files]
      return default_compose_files unless files.is_a?(Array)

      base_path = Hip.config.file_path&.parent || Pathname.new(Dir.pwd)

      files.filter_map do |file_path|
        file_path = Hip.env.interpolate(file_path)
        path = Pathname.new(file_path)
        path = base_path.join(path).expand_path if path.relative?
        path if path.exist?
      end
    end

    # Find default compose files when none specified in hip.yml
    #
    # @return [Array<Pathname>] Default compose files if they exist
    def default_compose_files
      base_path = Hip.config.file_path&.parent || Pathname.new(Dir.pwd)

      %w[docker-compose.yml docker-compose.yaml compose.yml compose.yaml].filter_map do |filename|
        path = base_path.join(filename)
        path if path.exist?
      end
    end

    # Parse all compose files and merge services
    #
    # @return [Hash] Merged services from all compose files
    def parse_all_files
      merged = {}

      compose_files.each do |path|
        data = parse_yaml_file(path)
        next unless data.is_a?(Hash)

        file_services = data["services"] || {}
        # Later files override earlier ones (docker-compose standard behavior)
        file_services.each do |name, config|
          merged[name] = if merged[name].is_a?(Hash) && config.is_a?(Hash)
            merged[name].merge(config)
          else
            config
          end
        end
      end

      merged
    end

    # Parse a single YAML file safely
    #
    # @param path [Pathname] Path to YAML file
    # @return [Hash, nil] Parsed YAML data or nil on error
    def parse_yaml_file(path)
      content = File.read(path)

      if Gem::Version.new(Psych::VERSION) >= Gem::Version.new("4.0.0")
        YAML.safe_load(content, aliases: true, permitted_classes: [Symbol])
      else
        YAML.safe_load(content, [], [], true)
      end
    rescue Psych::SyntaxError => e
      DebugLogger.log_error("ComposeFileParser#parse_yaml_file", e, file: path.to_s)
      nil
    rescue Errno::ENOENT => e
      DebugLogger.log_error("ComposeFileParser#parse_yaml_file", e, file: path.to_s)
      nil
    rescue => e
      DebugLogger.log_error("ComposeFileParser#parse_yaml_file", e, file: path.to_s)
      nil
    end
  end
end
