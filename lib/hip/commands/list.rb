# frozen_string_literal: true

require_relative "../command"
require_relative "../interaction_tree"
require "json"
require "yaml"

module Hip
  module Commands
    class List < Hip::Command
      def initialize(format: "table", detailed: false)
        @format = format
        @detailed = detailed
      end

      def execute
        tree = InteractionTree.new(Hip.config.interaction).list

        case @format
        when "json"
          output_json(tree)
        when "yaml"
          output_yaml(tree)
        else
          output_table(tree)
        end
      end

      private

      attr_reader :format, :detailed

      def output_table(tree)
        if detailed
          output_detailed_table(tree)
        else
          output_simple_table(tree)
        end
      end

      def output_simple_table(tree)
        longest_name = tree.keys.map(&:size).max

        tree.each do |name, command|
          puts "#{name.ljust(longest_name)}  ##{" #{command[:description]}" if command[:description]}"
        end
      end

      def output_detailed_table(tree)
        longest_name = tree.keys.map(&:size).max
        longest_runner = tree.values.map { |c| runner_name(c).size }.max

        tree.each do |name, command|
          runner = runner_name(command).ljust(longest_runner)
          target = target_name(command)
          cmd = command[:command]

          puts "#{name.ljust(longest_name)}  [#{runner}]  #{target}  #{cmd}"
          puts " " * (longest_name + 2) + "# #{command[:description]}" if command[:description]
        end
      end

      def output_json(tree)
        data = tree.transform_values do |command|
          format_command_data(command)
        end
        puts JSON.pretty_generate(data)
      end

      def output_yaml(tree)
        data = tree.transform_values do |command|
          format_command_data(command)
        end
        puts YAML.dump(data)
      end

      def format_command_data(command)
        data = {
          description: command[:description],
          command: command[:command],
          runner: runner_name(command),
          shell: command[:shell]
        }

        data[:service] = command[:service] if command[:service]
        data[:pod] = command[:pod] if command[:pod]
        data[:workdir] = command[:workdir] if command[:workdir]
        data[:user] = command[:user] if command[:user]
        data[:entrypoint] = command[:entrypoint] if command[:entrypoint]
        data[:compose_method] = command.dig(:compose, :method) if command[:service]
        data[:environment] = command[:environment] if command[:environment]&.any?

        data.compact
      end

      def runner_name(command)
        if command[:runner]
          command[:runner].split("_").map(&:capitalize).join
        elsif command[:service]
          "DockerCompose"
        elsif command[:pod]
          "Kubectl"
        else
          "Local"
        end
      end

      def target_name(command)
        if command[:service]
          "service:#{command[:service]}"
        elsif command[:pod]
          "pod:#{command[:pod]}"
        else
          "local"
        end
      end
    end
  end
end
