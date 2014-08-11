$:.push File.join(File.dirname(__FILE__), '..', 'lib')
Thread.abort_on_exception = true

%w(
  adhearsion
  electric_slide
  rspec/core
).each { |r| require r }

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

def dummy_call
  Object.new
end

