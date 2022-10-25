# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)
require 'electric_slide/version'
require 'date'

Gem::Specification.new do |s|
  s.name = "electric_slide"
  s.version = ElectricSlide::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ben Klang"]

  s.date = Date.today.to_s
  s.description = "Automatic Call Distributor (ACD) for Adhearsion. Currently implements only Round Robin distribution strategies."
  s.email = "dev&adhearsion.com"

  s.files = `git ls-files`.split("\n")

  s.has_rdoc = true
  s.homepage = "http://github.com/adhearsion/electric_slide"
  s.license = "MIT"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.2.0"
  s.summary = "Automatic Call Distributor for Adhearsion"

  s.add_runtime_dependency 'adhearsion', ['~> 2.4']
  s.add_runtime_dependency 'countdownlatch'
  s.add_runtime_dependency 'activesupport'
  s.add_development_dependency 'rspec', ['~> 3.0']
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'ci_reporter'
  s.add_development_dependency 'guard'
  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'simplecov-rcov'

  # These two are needed to keep compatibility with Ruby >= 2.2.0, <= 2.2.3
  s.add_development_dependency 'ruby_dep', ['= 1.3.1']
  s.add_development_dependency 'listen', ['<= 3.1.1']

  s.specification_version = 2
end
