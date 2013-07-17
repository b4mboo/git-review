$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'
require 'support/assumptions'
require 'support/request_context'
require 'support/private_context'

RSpec.configure do |config|
  # Standard values for a nice output.
  config.color_enabled = true
  # Silence console output for all specs.
  config.before { assume_silence }
end
