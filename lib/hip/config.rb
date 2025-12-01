# frozen_string_literal: true

require "yaml"
require "erb"
require "pathname"
require "json-schema"

require "hip/version"
require "hip/ext/hash"
require "hip/env_file_loader"

using ActiveSupportHashHelpers

module Hip
  class Config
    DEFAULT_PATH = "hip.yml"

    CONFIG_DEFAULTS = {
      environment: {},
      env_file: nil,
      compose: {},
      kubectl: {},
      infra: {},
      interaction: {},
      provision: [],
      devcontainer: {}
    }.freeze

    TOP_LEVEL_KEYS = %i[environment env_file compose kubectl infra interaction provision devcontainer].freeze

    ConfigKeyMissingError = Class.new(ArgumentError)

    class ConfigFinder
      attr_reader :file_path

      def initialize(work_dir, override: false)
        @override = override

        @file_path = if ENV["HIP_FILE"]
          Pathname.new(prepared_name(ENV["HIP_FILE"]))
        else
          find(Pathname.new(work_dir))
        end
      end

      def exist?
        file_path&.exist?
      end

      def modules_dir
        file_path.dirname / ".hip"
      end

      private

      attr_reader :override

      def prepared_name(path)
        return path unless override

        path.gsub(/\.yml$/, ".override.yml")
      end

      def find(path)
        file = path.join(prepared_name(DEFAULT_PATH))
        return file if file.exist?
        return if path.root?

        find(path.parent)
      end
    end

    class << self
      def load_yaml(file_path = path)
        return {} unless File.exist?(file_path)

        data = if Gem::Version.new(Psych::VERSION) >= Gem::Version.new("4.0.0")
          YAML.safe_load(
            ERB.new(File.read(file_path)).result,
            aliases: true
          )
        else
          YAML.safe_load(
            ERB.new(File.read(file_path)).result,
            [], [], true
          )
        end

        data&.deep_symbolize_keys! || {}
      end
    end

    def initialize(work_dir = Dir.pwd)
      @work_dir = work_dir
    end

    def file_path
      finder.file_path
    end

    def module_file(filename)
      finder.modules_dir / "#{filename}.yml"
    end

    def exist?
      finder.exist?
    end

    def to_h
      config
    end

    TOP_LEVEL_KEYS.each do |key|
      define_method(key) do
        config[key] || (raise config_missing_error(key))
      end
    end

    def validate
      raise Hip::Error, "Config file path is not set" if file_path.nil?
      raise Hip::Error, "Config file not found: #{file_path}" unless File.exist?(file_path)

      schema_path = File.join(File.dirname(__FILE__), "../../schema.json")
      raise Hip::Error, "Schema file not found: #{schema_path}" unless File.exist?(schema_path)

      data = self.class.load_yaml(file_path)
      schema = JSON::Validator.parse(File.read(schema_path))
      JSON::Validator.validate!(schema, data)
    rescue Psych::SyntaxError => e
      raise Hip::Error, "Invalid YAML syntax in config file: #{e.message}"
    rescue JSON::Schema::ValidationError => e
      error_message = format_validation_error(e, data)
      raise Hip::Error, error_message
    rescue JSON::Schema::JsonParseError => e
      raise Hip::Error, "Error parsing schema file: #{e.message}"
    end

    def format_validation_error(error, data)
      message = error.message

      # Extract the property path and error details
      if message =~ /The property '#\/([^']+)'/
        property_path = ::Regexp.last_match(1)
        property_value = extract_property_value(data, property_path)

        error_msg = <<~ERROR
          Schema validation failed in hip.yml

          Property: #{property_path}
          Error: #{message}

          Current value:
          #{format_yaml_snippet(property_value)}

          Hint: Run 'hip validate' for detailed validation
               Use HIP_DEBUG=1 to see full config dump
        ERROR

        error_msg.strip
      else
        # Fallback to simple message
        "Schema validation failed: #{message}\n\nRun 'hip validate' for more details"
      end
    end

    def extract_property_value(data, path)
      parts = path.split("/")
      value = data

      parts.each do |part|
        # Handle array indices like "provision/default/2"
        if part =~ /^\d+$/
          value = value[part.to_i] if value.is_a?(Array)
        elsif value.is_a?(Hash)
          value = value[part.to_sym]
        end
        break if value.nil?
      end

      value
    end

    def format_yaml_snippet(value)
      return "  (not found)" if value.nil?

      yaml_str = value.to_yaml.strip
      lines = yaml_str.lines

      # Limit to 10 lines for readability
      if lines.size > 10
        lines[0..9].join.strip + "\n  ... (#{lines.size - 10} more lines)"
      else
        "  " + yaml_str.gsub("\n", "\n  ")
      end
    end

    private

    attr_reader :work_dir

    def finder
      @finder ||= ConfigFinder.new(work_dir)
    end

    def config
      return @config if @config

      raise Hip::Error, "Could not find hip.yml config" unless finder.exist?

      config = self.class.load_yaml(finder.file_path)

      unless Gem::Version.new(Hip::VERSION) >= Gem::Version.new(config.fetch(:version))
        raise VersionMismatchError, "Your hip version is `#{Hip::VERSION}`, " \
                                   "but config requires minimum version `#{config[:version]}`. " \
                                   "Please upgrade your hip!"
      end

      base_config = {}

      if (modules = config[:modules])
        raise Hip::Error, "Modules should be specified as array" unless modules.is_a?(Array)

        modules.each do |m|
          file = module_file(m)
          raise Hip::Error, "Could not find module `#{m}`" unless file.exist?

          module_config = self.class.load_yaml(file)
          raise Hip::Error, "Nested modules are not supported" if module_config[:modules]

          base_config.deep_merge!(module_config)
        end
      end

      base_config.deep_merge!(config)

      override_finder = ConfigFinder.new(work_dir, override: true)
      base_config.deep_merge!(self.class.load_yaml(override_finder.file_path)) if override_finder.exist?

      @config = CONFIG_DEFAULTS.merge(base_config)

      # Only validate if explicitly requested or in debug mode
      # This improves startup performance
      unless ENV.key?("HIP_SKIP_VALIDATION")
        begin
          validate
        rescue Hip::Error => e
          # Show concise error message and exit
          warn "\n#{e.message}\n"
          exit 1
        end
      end

      @config
    end

    def config_missing_error(config_key)
      msg = "config for %<key>s is not defined in %<path>s" % {key: config_key, path: finder.file_path}
      ConfigKeyMissingError.new(msg)
    end
  end
end
