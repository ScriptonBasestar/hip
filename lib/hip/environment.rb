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

    def initialize(default_vars)
      @vars = {}

      merge(default_vars || {})
    end

    def merge(new_vars)
      new_vars.each do |key, value|
        key = key.to_s
        @vars[key] = ENV.fetch(key) { interpolate(value.to_s) }
      end
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
  end
end
