require_relative '../spec_helper'
require 'json'

class FakeResponse

  attr_accessor :code, :body

  def initialize(args)
    @code = args[:code]
    @body = args[:body]
  end

end

describe 'Github' do

  it 'is a singleton' do
    expect { ::GitReview::Github.new }.to raise_error(NoMethodError)
  end

  context 'github instance' do

    let(:foo) { ::GitReview::Request.new }
    let(:bar) { ::GitReview::Commit.new }
    let(:settings) { ::GitReview::Settings.send(:new) }
    let(:success_response) {
      FakeResponse.new(
          :code => '201',
          :body => { :token => 'some_valid_token' }.to_json
      )
    }
    let(:fail_response) { FakeResponse.new(:code => '401') }
    let(:error_response) { FakeResponse.new(:code => '999') }

    before(:each) do
      @github = ::GitReview::Github.send(:new)
    end

    it 'stringifies all arguments' do
      foo.stub(:to_s).and_return('foo')
      bar.stub(:to_s).and_return('bar')
      args = @github.send(:stringify, foo, bar)
      args.should == %w(foo bar)
    end

    context 'extracts username and project' do

      it 'from git url' do
        url = 'git@github.com:xystushi/git-review.git'
        result = @github.send(:github_url_matching, url)
        result.should == %w(xystushi git-review)
      end

      it 'from http url' do
        url = 'https://github.com/xystushi/git-review.git'
        result = @github.send(:github_url_matching, url)
        result.should == %w(xystushi git-review)
      end

      it 'from insteadof url' do
        url = 'git@github.com:foo/bar.git'
        config = {
            'url.git@github.com:a/b.git.insteadof' =>
                'git@github.com:foo/bar.git'
        }
        result = @github.send(:github_insteadof_matching, config, url)
        result.should == %w(git@github.com:foo/bar.git git@github.com:a/b.git)
      end

    end

    context 'authentication' do

      context 'when token exists' do

        it 'loads from settings automatically' do
          assume_token_present
          @github.configure_github_access
          @github.github.login.should == 'username'
          @github.github.oauth_token.should == 'some_valid_token'
        end

      end

      context 'when token does not exist' do

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
          expect { @github.send(:authorize) }.
              to raise_error(::GitReview::Errors::AuthenticationError)
        end

        it 'raises error on other responses' do
          Net::HTTP.any_instance.stub(:request).and_return(error_response)
          expect { @github.send(:authorize) }.
              to raise_error(::GitReview::Errors::UnprocessableState)
        end

      end

    end

  end

end