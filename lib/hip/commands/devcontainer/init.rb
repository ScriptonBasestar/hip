# frozen_string_literal: true

require_relative "../../command"
require_relative "../../devcontainer"

module Hip
  module Commands
    module DevContainer
      class Init < Hip::Command
        attr_reader :template, :force

        def initialize(template: nil, force: false)
          @template = template
          @force = force
        end

        def execute
          devcontainer = Hip::DevContainer.new

          if File.exist?(devcontainer.devcontainer_path) && !force
            raise Hip::Error, "DevContainer file already exists: #{devcontainer.devcontainer_path}\nUse --force to overwrite"
          end

          if template
            generate_from_template
          else
            devcontainer.generate
          end

          puts "✓ Generated #{devcontainer.devcontainer_path}"
          puts "\nNext steps:"
          puts "  1. Review and customize #{devcontainer.devcontainer_path}"
          puts "  2. Open this project in VSCode"
          puts "  3. VSCode will prompt to reopen in container"
        end

        private

        def generate_from_template
          template_path = find_template(template)
          raise Hip::Error, "Template '#{template}' not found" unless template_path

          devcontainer = Hip::DevContainer.new
          FileUtils.mkdir_p(File.dirname(devcontainer.devcontainer_path))

          # Load template and merge with hip.yml config
          template_config = JSON.parse(File.read(template_path))
          hip_config = devcontainer.send(:build_devcontainer_config)
          merged_config = template_config.merge(hip_config)

          devcontainer.send(:write_devcontainer_file, merged_config)
        end

        def find_template(name)
          template_file = "#{name}.json"
          template_dir = File.join(File.dirname(__FILE__), "../../templates/devcontainer")

          template_path = File.join(template_dir, template_file)
          return template_path if File.exist?(template_path)

          nil
        end
      end
    end
  end
end
