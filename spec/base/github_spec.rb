require 'spec_helper'
require 'json'

class FakeResponse

  attr_accessor :code, :body

  def initialize(args)
    @code = args[:code]
    @body = args[:body]
  end

end

describe Github do

  it 'is a singleton' do
    expect { Github.new }.to raise_error(NoMethodError)
  end

  context 'github instance' do

    subject { Github.send(:new) }
    let(:foo) { Request.new }
    let(:bar) { Commit.new }
    let(:settings) { Settings.send(:new) }
    let(:success_response) { FakeResponse.new(:code => '201', :body => {
        'token' => 'some_valid_token'
    }.to_json) }
    let(:fail_response) { FakeResponse.new(:code => '401') }
    let(:error_response) { FakeResponse.new(:code => '999') }

    before(:each) do
      @github = Github.instance
    end

    it 'stringifies all arguments' do
      foo.stub(:to_s).and_return('foo')
      bar.stub(:to_s).and_return('bar')
      args = subject.send(:stringify, foo, bar)
      args.should == ['foo', 'bar']
    end

    context 'authentication' do

      context 'with token present' do

        it 'loads from settings automatically' do
          assume_token_present
          @github.configure_github_access
          @github.github.login.should == 'username'
          @github.github.oauth_token.should == 'some_valid_token'
        end

      end

      context 'without token present' do

        it 'asks for username, password, and description' do
          assume_token_missing
          @github.stub(:authorize)
          @github.should_receive(:prepare_description)
          @github.should_receive(:prepare_username_and_password)
          @github.send(:configure_oauth)
        end

        it 'saves username and token to settings on success' do
          Net::HTTP.any_instance.stub(:request).and_return(success_response)
          @github.should_receive(:save_oauth_token).with('some_valid_token')
          @github.send(:authorize)
        end

        it 'raises error when username/password is incorrect' do
          Net::HTTP.any_instance.stub(:request).and_return(fail_response)
          expect { @github.send(:authorize) }.to raise_error(
                                                     Errors::AuthenticationError
                                                 )
        end

        it 'raises error on other responses' do
          Net::HTTP.any_instance.stub(:request).and_return(error_response)
          expect { @github.send(:authorize) }.to raise_error(
                                                     Errors::UnprocessableState
                                                 )
        end

      end

    end

  end

end