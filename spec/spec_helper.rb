$:.push File.join(File.dirname(__FILE__), '..', 'lib')
Thread.abort_on_exception = true

%w{
  adhearsion
  adhearsion/plugin/queue
  adhearsion/plugin/queue/queued_call
  adhearsion/plugin/queue/queue_strategy
  adhearsion/plugin/queue/round_robin
  rspec/core
  flexmock
  flexmock/rspec
}.each { |r| require r }

RSpec.configure do |config|
  config.mock_framework = :flexmock
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.color_enabled = true
end

def dummy_call
  Object.new
end

