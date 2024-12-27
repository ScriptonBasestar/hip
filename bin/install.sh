#!/usr/bin/env ruby

require_relative '../lib/dip/version'
#require 'dip/version'

puts Dip::VERSION

system("gem build dip.gemspec")

system("gem install dip-#{Dip::VERSION}.gem --user-install")
