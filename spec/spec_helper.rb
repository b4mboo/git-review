$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'
require 'rspec'
require_relative 'support/request_context'
