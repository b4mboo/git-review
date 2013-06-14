$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'
require 'rspec'
require_relative 'support/assumptions'
require_relative 'support/request_context'
require_relative 'support/private_context'

RSpec.configure do |config|
  # Standard values for a nice output.
  config.color_enabled = true
  config.formatter = :documentation
  # Silence console output for all specs.
  config.before { assume_silence }
end
