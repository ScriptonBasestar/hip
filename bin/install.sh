#!/usr/bin/env ruby

require_relative '../lib/hip/version'
#require 'hip/version'

puts Hip::VERSION

system("gem build hip.gemspec")

system("gem install hip-#{Hip::VERSION}.gem --user-install")
