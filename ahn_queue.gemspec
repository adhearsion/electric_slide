GEM_FILES = %w{
  ahn_queue.gemspec
  lib/ahn_queue.rb
  lib/ahn_queue/queue_strategy.rb
  lib/ahn_queue/round_robin.rb
  lib/ahn_queue/round_robin_meetme.rb
  config/ahn_queue.yml
}

Gem::Specification.new do |s|
  s.name = "ahn_queue"
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ben Klang"]

  s.date = Date.today.to_s
  s.description = "Automatic Call Distributor (ACD) for Adhearsion. Currently implements only Round Robin distribution strategies."
  s.email = "dev&adhearsion.com"

  s.files = GEM_FILES

  s.has_rdoc = true
  s.homepage = "http://github.com/adhearsion/ahn_queue"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.2.0"
  s.summary = "Automatic Call Distributor for Adhearsion"

  s.add_runtime_dependency 'adhearsion', ['~> 1.2.0']

  s.specification_version = 2
end
