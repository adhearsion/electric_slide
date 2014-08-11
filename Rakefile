#!/usr/bin/env ruby
# encoding: utf-8
# -*- ruby -*-
ENV['RUBY_FLAGS'] = "-I#{%w(lib ext bin spec).join(File::PATH_SEPARATOR)}"

require 'rubygems'
require 'bundler/gem_tasks'
require 'bundler/setup'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

task ci: ['ci:setup:rspec', :spec]
task default: :spec

