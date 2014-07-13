$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'git-review'
require 'rspec'
require 'hashie'

require_relative 'support/request_context'
require_relative 'support/commit_context'
require_relative 'support/comment_context'
