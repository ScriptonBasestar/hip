# frozen_string_literal: true

# @file: lib/hip/commands/clean.rb
# @purpose: Remove all containers, networks, and optionally volumes to resolve conflicts
# @flow: CLI -> Clean -> Compose down with cleanup flags
# @dependencies: Hip::Command, Hip::Commands::Compose
# @key_methods: execute (main entry), cleanup_options (build compose down flags)

require_relative "../command"
require_relative "compose"

module Hip
  module Commands
    class Clean < Hip::Command
      attr_reader :volumes, :images, :force

      def initialize(volumes: false, images: false, force: false)
        @volumes = volumes
        @images = images
        @force = force
      end

      def execute
        unless force
          warn "\n⚠️  This will remove all containers and networks"
          warn "   Add --volumes to also remove volumes"
          warn "   Add --images to also remove images"
          warn ""

          print "Continue? [y/N]: "
          response = $stdin.gets.chomp.downcase

          unless %w[y yes].include?(response)
            puts "Cancelled."
            return
          end
        end

        puts "\n🧹 Cleaning up Docker Compose resources..."

        compose_argv = cleanup_options

        Hip::Commands::Compose.new(*compose_argv).execute

        puts "\n✅ Cleanup complete"
      end

      private

      def cleanup_options
        argv = ["down", "--remove-orphans"]
        argv << "--volumes" if volumes
        argv << "--rmi" << "all" if images
        argv
      end
    end
  end
end
