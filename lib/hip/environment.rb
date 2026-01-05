# frozen_string_literal: true

# @file: lib/hip/environment.rb
# @purpose: Manage environment variables and interpolation in commands
# @flow: Hip.env -> Environment.new -> interpolate($VAR, ${VAR})
# @dependencies: pathname
# @key_methods: interpolate, merge (supports special vars: HIP_OS, HIP_WORK_DIR_REL_PATH, HIP_CURRENT_USER)

require "pathname"

module Hip
  class Environment
    VAR_REGEX = /\$\{?(?<var_name>[a-zA-Z_][a-zA-Z0-9_]*)\}?/
    SPECIAL_VARS = %i[os work_dir_rel_path current_user].freeze

    attr_reader :vars

    def initialize(default_vars, env_file_config: nil, base_path: nil)
      @vars = {}
      @env_file_config = env_file_config
      @base_path = base_path
      @delayed_env_file_vars = nil

      # Load env_file first (if configured)
      if env_file_config
        load_env_files
      end

      # Then merge default_vars (which can override env_file if priority is 'before_environment')
      merge_vars!(default_vars || {})

      # Apply delayed env_file vars if priority is 'after_environment'
      merge_env_file_vars(@delayed_env_file_vars) if @delayed_env_file_vars
    end

    def merge_vars!(new_vars)
      new_vars.each do |key, value|
        key = key.to_s
        @vars[key] = ENV.fetch(key) { interpolate(value.to_s) }
      end
      self
    end

    def merge(new_vars)
      Hip.logger.warn("Environment#merge is deprecated; use merge_vars! instead") unless Hip.test?
      merge_vars!(new_vars)
    end

    def [](name)
      vars.fetch(name) { ENV[name] }
    end

    def fetch(name, &block)
      vars.fetch(name) { ENV.fetch(name, &block) }
    end

    def []=(key, value)
      @vars[key] = value
    end

    def interpolate(value)
      value.gsub(VAR_REGEX) do |match|
        var_name = Regexp.last_match[:var_name]

        if special_vars.key?(var_name)
          fetch(var_name) { send(special_vars[var_name]) }
        else
          fetch(var_name) { match }
        end
      end
    end

    alias_method :replace, :interpolate

    private

    def special_vars
      @special_vars ||= SPECIAL_VARS.each_with_object({}) do |key, memo|
        memo["HIP_#{key.to_s.upcase}"] = "find_#{key}"
      end
    end

    def find_os
      @hip_os ||= Gem::Platform.local.os
    end

    def find_work_dir_rel_path
      @find_work_dir_rel_path ||= Pathname.getwd.relative_path_from(Hip.config.file_path.parent).to_s
    end

    def find_current_user
      @find_current_user ||= Process.uid
    end

    def load_env_files
      require "hip/env_file_loader"

      # Determine priority and interpolate settings
      priority = extract_priority(@env_file_config)
      interpolate = extract_interpolate(@env_file_config)

      # Load env_file variables
      env_file_vars = Hip::EnvFileLoader.load(
        @env_file_config,
        base_path: @base_path || Hip.config.file_path.parent,
        interpolate: interpolate
      )

      # Merge based on priority
      case priority
      when "before_environment"
        # env_file loaded first, environment: can override
        # Already happening in initialize order
        merge_env_file_vars(env_file_vars)
      when "after_environment"
        # environment: loaded first (in initialize), env_file overrides
        # We need to delay this merge until after default_vars
        @delayed_env_file_vars = env_file_vars
      else
        # Default: before_environment
        merge_env_file_vars(env_file_vars)
      end
    rescue Hip::Error => e
      raise e
    rescue => e
      raise Hip::Error, "Failed to load env_file: #{e.message}"
    end

    def merge_env_file_vars(env_vars)
      env_vars.each do |key, value|
        @vars[key.to_s] = value.to_s
      end
    end

    def extract_priority(config)
      return "before_environment" unless config.is_a?(Hash)

      config[:priority] || config["priority"] || "before_environment"
    end

    def extract_interpolate(config)
      return true unless config.is_a?(Hash)

      if config.key?(:interpolate)
        config[:interpolate]
      elsif config.key?("interpolate")
        config["interpolate"]
      else
        true
      end
    end
  end
end
