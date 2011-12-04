Gem::Specification.new do |s|
  s.name = "adhearsion-queue"
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ben Klang"]

  s.date = Date.today.to_s
  s.description = "Automatic Call Distributor (ACD) for Adhearsion. Currently implements only Round Robin distribution strategies."
  s.email = "dev&adhearsion.com"

  s.files = `git ls-files`.split("\n")

  s.has_rdoc = true
  s.homepage = "http://github.com/adhearsion/adhearsion-queue"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.2.0"
  s.summary = "Automatic Call Distributor for Adhearsion"

  s.add_runtime_dependency 'adhearsion'
  s.add_runtime_dependency 'countdownlatch'
  s.add_runtime_dependency 'activesupport'
  s.add_development_dependency 'rspec', ['>= 2.5.0']
  s.add_development_dependency 'flexmock', ['>= 0.9.0']
  s.add_development_dependency 'ci_reporter'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'simplecov-rcov'

  s.specification_version = 2
end
