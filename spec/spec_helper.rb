$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'git-review'
require 'rspec'
require 'hashie'
require 'webmock/rspec'

require_relative 'support/request_context'

RSpec.configure do |config|

    MOCK_USER = 'foo'
    MOCK_PASSWORD = 'bar'
    MOCK_DESCRIPTION = ' '
    MOCK_OTP = '1234567890'

    config.before(:each) do
        @saved_stdin = $stdin
        $stdin = StringIO.new "#{MOCK_USER}\n#{MOCK_PASSWORD}\n#{MOCK_DESCRIPTION}\n#{MOCK_OTP}\n"
        stub_request(:post, /https:\/\/.*:.*@api.github.com\/authorizations/).to_return(:status => 401,headers: {'X-GitHub-OTP' => "required;sms"})
        stub_request(:post, /https:\/\/.*:.*@api.github.com\/authorizations/).with(headers: {'X-GitHub-OTP' => /.*/ }).to_return(:status => 201,body:"{\"token\": 123456789}")
    end
    config.after(:each) do
        $stdin = @saved_stdin
    end
end

