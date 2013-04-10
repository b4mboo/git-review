$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'
require 'support/request_context'
require 'support/assumptions'

RSpec.configure do |config|
  # Standard values for a nice output.
  config.color_enabled = true
  config.formatter = :documentation
  # Allow to re-initialize an instance to be able to mock/stub it in tests.
  config.before :all do
    GitReview.define_method :init do
      initialize @args
    end
  end
  # Silence console output for all specs.
  config.before :each do
    assume_silence
  end
end
