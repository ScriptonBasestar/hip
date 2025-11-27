# frozen_string_literal: true

require "bundler/gem_tasks"

# Override install tasks to skip RDoc generation (avoids RDoc version conflicts)
# This prevents ArgumentError from RDoc parser incompatibility with Ruby 3.3+
Rake::Task["install"].clear
Rake::Task["install:local"].clear

desc "Build and install hip.gem into system gems without RDoc"
task install: :build do
  require "tmpdir"
  Dir.chdir(Dir.tmpdir) do
    built_gem_path = File.join(File.dirname(__FILE__), "pkg", "#{Bundler::GemHelper.gemspec.full_name}.gem")
    sh "gem install '#{built_gem_path}' --no-document"
  end
end

namespace :install do
  desc "Build and install hip.gem into system gems without network access and without RDoc"
  task local: :build do
    require "tmpdir"
    Dir.chdir(Dir.tmpdir) do
      built_gem_path = File.join(File.dirname(__FILE__), "pkg", "#{Bundler::GemHelper.gemspec.full_name}.gem")
      sh "gem install '#{built_gem_path}' --local --no-document"
    end
  end
end
