# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dip/version"

Gem::Specification.new do |spec|
  spec.name = "dip"
  spec.license = "MIT"
  spec.version = Dip::VERSION
  spec.authors = ["bibendi"]
  spec.email = ["merkushin.m.s@gmail.com"]

  spec.summary = "Ruby gem CLI tool for better interacting Docker Compose files."
  spec.description = "DIP - Docker Interaction Process." \
                       "CLI tool for better development experience when interacting with docker and Docker Compose."
  spec.homepage = "https://github.com/bibendi/dip"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org/"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.glob("lib/**/*") + Dir.glob("exe/*") + %w[LICENSE.txt README.md schema.json]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"

  spec.add_dependency "thor", ">= 0.20", "< 2"
  spec.add_dependency "json-schema", "~> 5"
  # public_suffix >= 6.0 requires Ruby >= 3.0, so we need to specify an upper bound
  # to maintain compatibility with Ruby 2.7
  spec.add_dependency "public_suffix", ">= 2.0.2", "< 6.0"

  spec.add_development_dependency "bundler", "~> 2.5"
  spec.add_development_dependency "pry-byebug", "~> 3"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "standard", "~> 1.0"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "rubocop-rspec", "~> 2.31"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "test-unit", "~> 3.6"
  spec.add_development_dependency "fakefs", "~> 2.8"
end
