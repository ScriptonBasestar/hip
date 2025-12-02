# frozen_string_literal: true

# @file: lib/hip/commands/migrate.rb
# @purpose: Generate LLM-friendly migration prompts for hip.yml version upgrades
# @flow: CLI -> Migrate -> Analyzer -> PromptBuilder -> Output
# @dependencies: hip/command, hip/config, yaml, json
# @key_methods: execute (main entry), analyze_config, build_prompt

require_relative "../command"
require "yaml"
require "json"

module Hip
  module Commands
    class Migrate < Hip::Command
      LATEST_VERSION = Hip::VERSION

      def initialize(to: nil, summary: false)
        @target_version = to || LATEST_VERSION
        @summary_mode = summary # TODO: --summary not implemented yet (future enhancement)
      end

      def execute
        unless Hip.config.exist?
          warn "ERROR: No hip.yml found in current directory or parent directories"
          exit 1
        end

        current_version = Hip.config.version || "unknown"

        if version_compare(current_version, @target_version) >= 0
          puts "✅ Your hip.yml is already at version #{current_version}"
          puts "   Target version: #{@target_version}"
          return
        end

        analysis = analyze_config
        prompt = build_prompt(current_version, analysis)

        puts prompt
      end

      private

      def analyze_config
        config = Hip.config.raw_config
        issues = []

        # Check for deprecated compose_run_options
        config["interaction"]&.each do |name, cmd|
          next unless cmd.is_a?(Hash)

          if cmd["compose_run_options"]
            issues << {
              type: :deprecated,
              feature: "compose_run_options",
              location: "interaction.#{name}",
              current: cmd["compose_run_options"],
              replacement: "compose.run_options"
            }
          end
        end

        # Check for legacy provision format
        config["provision"]&.each do |profile, steps|
          next unless steps.is_a?(Array)

          legacy_count = steps.count { |step| step.is_a?(String) && step.start_with?("echo") }
          if legacy_count > 0
            issues << {
              type: :legacy_format,
              feature: "provision",
              location: "provision.#{profile}",
              legacy_count: legacy_count,
              total_steps: steps.size
            }
          end
        end

        # Detect available new features
        new_features = []

        # env_file feature (v9.1.3+)
        has_env_file = config["env_file"] || config["interaction"]&.any? { |_, cmd| cmd.is_a?(Hash) && cmd["env_file"] }
        new_features << :env_file unless has_env_file

        {
          issues: issues,
          new_features: new_features,
          config_path: Hip.config.config_path,
          schema_path: File.expand_path("../../schema.json", __dir__),
          examples_dir: File.expand_path("../../examples", __dir__)
        }
      end

      def build_prompt(current_version, analysis)
        prompt = []

        prompt << "# Hip Configuration Migration Guide\n"
        prompt << "## Current Configuration"
        prompt << "- **File**: #{analysis[:config_path]}"
        prompt << "- **Current Version**: #{current_version}"
        prompt << "- **Latest Version**: #{LATEST_VERSION}"
        prompt << "- **Migration Required**: YES\n"
        prompt << "---\n"

        # Breaking changes and deprecations
        if analysis[:issues].any?
          prompt << "## Breaking Changes & Deprecations\n"

          analysis[:issues].each_with_index do |issue, idx|
            case issue[:type]
            when :deprecated
              prompt << "### #{idx + 1}. #{issue[:feature]} (Deprecated)"
              prompt << "**Status**: ⚠️ DEPRECATED - still works but will be removed in future versions\n"
              prompt << "**Location**: `#{issue[:location]}`"
              prompt << "**Current usage**:"
              prompt << "```yaml"
              prompt << "#{issue[:feature]}: #{issue[:current].inspect}"
              prompt << "```\n"
              prompt << "**Migrate to**:"
              prompt << "```yaml"
              prompt << "compose:"
              prompt << "  run_options: #{issue[:current].inspect}"
              prompt << "```\n"
              prompt << "**Schema reference**: schema.json:156-163\n"

            when :legacy_format
              prompt << "### #{idx + 1}. Provision Legacy Format"
              prompt << "**Status**: ⚠️ Consider migrating to step/run/note syntax (v9.2.0+)\n"
              prompt << "**Location**: `#{issue[:location]}`"
              prompt << "**Legacy steps**: #{issue[:legacy_count]} of #{issue[:total_steps]} steps use echo commands\n"
              prompt << "**Benefits of new syntax**:"
              prompt << "- ✅ No repetitive echo commands"
              prompt << "- ✅ No quote escaping issues"
              prompt << "- ✅ Automatic progress indicators (📦 [1/4])"
              prompt << "- ✅ Backward compatible\n"
              prompt << "**Example migration**:"
              prompt << "```yaml"
              prompt << "# Before (legacy)"
              prompt << "provision:"
              prompt << "  default:"
              prompt << "    - echo '📦 Installing dependencies...'"
              prompt << "    - bundle install"
              prompt << ""
              prompt << "# After (step syntax)"
              prompt << "provision:"
              prompt << "  default:"
              prompt << "    - step: Installing dependencies"
              prompt << "      run: bundle install"
              prompt << "```\n"
              prompt << "**Full example**: #{File.join(analysis[:examples_dir], "provision-step-syntax.yml")}"
              prompt << "**Documentation**: CHANGELOG.md:10-44\n"
            end
          end

          prompt << "---\n"
        end

        # New features available
        if analysis[:new_features].any?
          prompt << "## New Features Available\n"

          if analysis[:new_features].include?(:env_file)
            prompt << "### env_file Support (v9.1.3+)"
            prompt << "**New capability**: Load environment variables from .env files\n"
            prompt << "**Usage**:"
            prompt << "```yaml"
            prompt << "# Simple"
            prompt << "env_file: .env"
            prompt << ""
            prompt << "# Multiple files (later overrides earlier)"
            prompt << "env_file:"
            prompt << "  - .env.defaults"
            prompt << "  - .env"
            prompt << "  - .env.local"
            prompt << ""
            prompt << "# Advanced (priority control)"
            prompt << "env_file:"
            prompt << "  files: [.env.defaults, .env]"
            prompt << "  priority: before_environment  # or after_environment"
            prompt << "  required: false"
            prompt << "  interpolate: true"
            prompt << "```\n"
            prompt << "**Examples**:"
            prompt << "- #{File.join(analysis[:examples_dir], "env-file-basic.yml")}"
            prompt << "- #{File.join(analysis[:examples_dir], "env-file-priority.yml")}"
            prompt << "- #{File.join(analysis[:examples_dir], "env-file-multi-env.yml")}\n"
            prompt << "**Schema reference**: schema.json:20-99\n"
          end

          prompt << "---\n"
        end

        # Validation results
        prompt << "## Validation\n"
        begin
          Hip.config.validate
          prompt << "✅ Your current configuration is valid."
          if analysis[:issues].any?
            prompt << "⚠️ However, you're using deprecated/legacy features (see above).\n"
          end
        rescue Hip::Error => e
          prompt << "❌ Validation failed: #{e.message}"
          prompt << "⚠️ Fix validation errors before migrating.\n"
        end
        prompt << "---\n"

        # Migration checklist
        prompt << "## Migration Checklist\n"
        prompt << "- [ ] Update `version: '#{current_version}'` → `version: '#{@target_version}'`"

        analysis[:issues].each do |issue|
          case issue[:type]
          when :deprecated
            prompt << "- [ ] Replace `#{issue[:feature]}` with `#{issue[:replacement]}` in `#{issue[:location]}`"
          when :legacy_format
            prompt << "- [ ] Migrate `#{issue[:location]}` to step/run/note syntax (optional but recommended)"
          end
        end

        analysis[:new_features].each do |feature|
          prompt << "- [ ] Consider using #{feature} feature (optional)"
        end

        prompt << "- [ ] Run `hip validate` to verify changes"
        prompt << "- [ ] Test provision: `hip provision`\n"
        prompt << "---\n"

        # Reference documentation
        prompt << "## Reference Documentation\n"
        prompt << "### Schema & Examples"
        prompt << "- **Schema**: #{analysis[:schema_path]}"
        prompt << "- **Latest Example**: #{File.join(analysis[:examples_dir], "provision-step-syntax.yml")}"
        prompt << "- **Your Current Config**: #{analysis[:config_path]}\n"
        prompt << "### Version History"
        prompt << "- v9.2.0: Provision step syntax"
        prompt << "- v9.1.3: env_file support, auto-start containers"
        prompt << "- v9.1.2: Smart container detection"
        prompt << "- v9.0.0: compose_run_options deprecated\n"
        prompt << "**Full Changelog**: #{File.join(File.dirname(analysis[:schema_path]), "CHANGELOG.md")}\n"
        prompt << "---\n"

        prompt << "**Generated by**: hip v#{Hip::VERSION}"
        prompt << "**Date**: #{Time.now.strftime("%Y-%m-%d")}"

        prompt.join("\n")
      end

      # Simple version comparison (assumes semver format)
      def version_compare(v1, v2)
        return 0 if v1 == v2 || v1 == "unknown" || v2 == "unknown"

        parts1 = v1.split(".").map(&:to_i)
        parts2 = v2.split(".").map(&:to_i)

        [parts1.size, parts2.size].max.times do |i|
          p1 = parts1[i] || 0
          p2 = parts2[i] || 0
          return p1 <=> p2 if p1 != p2
        end

        0
      end
    end
  end
end
