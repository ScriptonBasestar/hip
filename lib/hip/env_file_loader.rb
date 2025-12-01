# frozen_string_literal: true

# @file: lib/hip/env_file_loader.rb
# @purpose: Load and parse .env files for environment variable configuration
# @flow: Hip::Config -> EnvFileLoader.load -> parse .env files -> return Hash
# @dependencies: pathname
# @key_methods: load, parse_file, parse_line

require "pathname"

module Hip
  class EnvFileLoader
    # Regex for parsing .env file lines
    # Matches: KEY=value, KEY="value", KEY='value', KEY=
    LINE_REGEX = /\A
      (?:export\s+)?           # Optional 'export' prefix (ignored)
      (?<key>[A-Z_][A-Z0-9_]*) # Key: uppercase letters, numbers, underscores
      =                         # Equals sign
      (?<value>.*?)             # Value: anything (lazy match)
      \z
    /x

    # Regex for variable interpolation: $VAR or ${VAR}
    VAR_REGEX = /\$\{?([A-Z_][A-Z0-9_]*)\}?/

    class << self
      # Load environment variables from one or more .env files
      #
      # @param config [String, Array, Hash] env_file configuration
      # @param base_path [Pathname] base directory for relative paths
      # @param interpolate [Boolean] whether to interpolate variables
      # @return [Hash] merged environment variables
      def load(config, base_path:, interpolate: true)
        files = normalize_config(config)
        env_vars = {}

        files.each do |file_config|
          path = resolve_path(file_config[:path], base_path)
          required = file_config[:required]

          if !path.exist?
            handle_missing_file(path, required)
            next
          end

          unless path.readable?
            raise Hip::Error, "Environment file is not readable: #{path}"
          end

          Hip.logger.debug "Loading env_file: #{path}"
          file_vars = parse_file(path)
          env_vars.merge!(file_vars)
        end

        # Interpolate variables if enabled
        if interpolate
          env_vars = interpolate_vars(env_vars)
        end

        Hip.logger.debug "Loaded #{env_vars.size} variables from env_file(s)"
        env_vars
      end

      private

      # Normalize config to array of {path:, required:} hashes
      def normalize_config(config)
        case config
        when String
          [{path: config, required: false}]
        when Array
          config.map do |item|
            case item
            when String
              {path: item, required: false}
            when Hash
              {
                path: item[:path] || item["path"],
                required: item[:required] || item["required"] || false
              }
            else
              raise Hip::Error, "Invalid env_file item: #{item.inspect}"
            end
          end
        when Hash
          files = config[:files] || config["files"]
          required = config[:required] || config["required"] || false

          normalize_config(files).map do |f|
            f.merge(required: f[:required] || required)
          end
        else
          raise Hip::Error, "Invalid env_file config: #{config.inspect}"
        end
      end

      # Resolve file path relative to base_path
      def resolve_path(path_str, base_path)
        path = Pathname.new(path_str)
        return path if path.absolute?

        base_path.join(path).expand_path
      end

      # Handle missing file based on required flag
      def handle_missing_file(path, required)
        if required
          raise Hip::Error, "Required environment file not found: #{path}"
        else
          Hip.logger.debug "Optional env_file not found (skipping): #{path}"
        end
      end

      # Parse a single .env file
      def parse_file(path)
        env_vars = {}

        File.readlines(path, chomp: true).each_with_index do |line, index|
          line_number = index + 1

          # Skip empty lines and comments
          next if line.strip.empty?
          next if line.strip.start_with?("#")

          # Parse line
          key, value = parse_line(line)

          if key.nil?
            Hip.logger.warn "Invalid line in #{path}:#{line_number}: #{line}"
            next
          end

          env_vars[key] = value
        end

        env_vars
      rescue Errno::ENOENT
        raise Hip::Error, "Environment file not found: #{path}"
      rescue Errno::EACCES
        raise Hip::Error, "Permission denied reading environment file: #{path}"
      rescue => e
        raise Hip::Error, "Error reading environment file #{path}: #{e.message}"
      end

      # Parse a single line from .env file
      # Returns [key, value] or [nil, nil] if invalid
      def parse_line(line)
        match = line.match(LINE_REGEX)
        return [nil, nil] unless match

        key = match[:key]
        value = match[:value].strip

        # Handle quoted values
        value = unquote(value)

        [key, value]
      end

      # Remove surrounding quotes from value
      def unquote(value)
        # Single quotes: no escape sequences
        if value.start_with?("'") && value.end_with?("'")
          return value[1..-2]
        end

        # Double quotes: unescape sequences
        if value.start_with?('"') && value.end_with?('"')
          value = value[1..-2]
          # Process escape sequences: \\ must be done first to avoid double-unescaping
          value = value.gsub("\\\\", "\x00") # Temporary placeholder for \\
            .gsub('\\n', "\n")
            .gsub('\\t', "\t")
            .gsub('\\r', "\r")
            .gsub('\\"', '"')
            .gsub("\x00", "\\") # Replace placeholder with single \
          return value
        end

        value
      end

      # Interpolate variables in env_vars
      # Replaces $VAR and ${VAR} with values from env_vars or ENV
      def interpolate_vars(env_vars)
        # Multiple passes to handle nested references
        max_iterations = 10
        iteration = 0

        loop do
          iteration += 1
          changed = false

          env_vars.each do |key, value|
            next unless value.is_a?(String)

            new_value = value.gsub(VAR_REGEX) do |match|
              var_name = ::Regexp.last_match(1)

              # Look up in env_vars first, then ENV, then leave as-is
              replacement = env_vars[var_name] || ENV[var_name] || match
              changed = true if replacement != match
              replacement
            end

            env_vars[key] = new_value if new_value != value
          end

          break if !changed || iteration >= max_iterations
        end

        if iteration >= max_iterations
          Hip.logger.warn "Variable interpolation reached maximum iterations (possible circular reference)"
        end

        env_vars
      end
    end
  end
end
