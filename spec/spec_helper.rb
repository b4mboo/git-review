$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'
require 'support/assumptions'
require 'support/request_context'
require 'support/private_context'

RSpec.configure do |config|
  # Silence console output for all specs.
  config.before { assume_silence }
end
