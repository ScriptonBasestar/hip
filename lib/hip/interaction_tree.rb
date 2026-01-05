# frozen_string_literal: true

# @file: lib/hip/interaction_tree.rb
# @purpose: Parse and lookup commands from hip.yml interaction: hierarchy
# @flow: Config.interaction -> InteractionTree.new -> find(cmd, *argv)
# @dependencies: shellwords, hip/ext/hash
# @key_methods: find (recursive lookup), list (flatten all commands)

require "shellwords"
require "hip/ext/hash"

using ActiveSupportHashHelpers

module Hip
  class InteractionTree
    def initialize(entries)
      @entries = entries
    end

    def find(name, *argv)
      entry = entries[name.to_sym]
      return unless entry

      commands = expand(name.to_s, entry)

      keys = [name, *argv]
      rest = []

      keys.size.times do
        if (command = commands[keys.join(" ")])
          return {command: command, argv: rest.reverse!}
        else
          rest << keys.pop
        end
      end

      nil
    end

    def list
      entries.each_with_object({}) do |(name, entry), memo|
        expand(name.to_s, entry, tree: memo)
      end
    end

    private

    attr_reader :entries

    def expand(name, entry, tree: {})
      cmd = build_command(entry)

      tree[name] = cmd
      base_cmd = entry.except(:subcommands)

      entry[:subcommands]&.each do |sub_name, sub_entry|
        sub_command_defaults!(sub_entry)
        expand("#{name} #{sub_name}", base_cmd.deep_merge(sub_entry), tree: tree)
      end

      tree
    end

    def build_command(entry)
      command = entry.dup
      command.delete(:subcommands)

      command[:service] = entry[:service]

      command[:command] = entry[:command].to_s.strip
      command[:shell] = entry.fetch(:shell, true)
      command[:default_args] = entry[:default_args].to_s.strip
      command[:environment] = entry[:environment] || {}
      command[:compose] = normalize_compose(entry)

      command
    end

    def sub_command_defaults!(entry)
      entry[:command] ||= nil
      entry[:default_args] ||= nil
      entry[:subcommands] ||= nil
      entry[:description] ||= nil
    end

    def compose_run_options(value)
      return [] unless value

      value.map do |o|
        o = o.start_with?("-") ? o : "--#{o}"
        o.shellsplit
      end.flatten
    end

    def normalize_compose(entry)
      compose = entry[:compose].is_a?(Hash) ? entry[:compose].dup : {}
      compose[:method] = entry.dig(:compose, :method) || entry[:compose_method] || "run"
      compose[:profiles] = Array(entry.dig(:compose, :profiles))
      compose[:run_options] = compose_run_options(entry.dig(:compose, :run_options) || entry[:compose_run_options])
      compose
    end
  end
end
