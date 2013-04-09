$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'git-review'
require 'helpers/request_context'
require 'helpers/assumptions'

RSpec.configure do |config|
  # Standard values for a nice output.
  config.color_enabled = true
  config.formatter = :documentation
  # Silence console output for all specs.
  config.before { assume_silence }
end
