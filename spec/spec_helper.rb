$:.push File.join(File.dirname(__FILE__), '..', 'lib')
Thread.abort_on_exception = true

%w(
  adhearsion
  electric_slide
  rspec/core
  timecop
).each { |r| require r }

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.raise_errors_for_deprecations!

  config.after :each do
    Timecop.return
  end
end

def dummy_call
  Adhearsion::Call.new
end

