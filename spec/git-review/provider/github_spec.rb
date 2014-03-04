require_relative '../../spec_helper'

describe 'Provider: Github' do

  include_context 'request_context'

  subject { ::GitReview::Provider::Github.new(server) }

  let(:server) { ::GitReview::Server.any_instance }
  let(:settings) { ::GitReview::Settings.any_instance }
  let(:local) { ::GitReview::Local.any_instance }
  let(:client) { Octokit::Client.any_instance }

  before :each do
    ::GitReview::Provider::Github.any_instance.stub :git_call
    settings.stub(:oauth_token).and_return('token')
    settings.stub(:username).and_return(user_login)
  end

  context '# Authentication' do

    it 'identifies github user name if present' do
      github = ::GitReview::Provider::Github.any_instance
      settings.stub :oauth_token
      settings.stub :username
      github.stub :print_auth_message
      github.stub :prepare_password
      github.stub :prepare_description
      github.stub :authorize
      github.should_receive(:github_login).and_return('existing_user')
      github.should_not_receive(:prepare_username)
      subject
    end

    it 'configures access to GitHub' do
      ::GitReview::Provider::Github.any_instance.should_receive :configure_access
      subject
    end

    it 'uses an oauth token for authentication' do
      settings.stub :oauth_token
      settings.stub :username
      ::GitReview::Provider::Github.any_instance.should_receive :configure_oauth
      subject
    end

    it 'uses Octokit to login to GitHub' do
      settings.stub(:oauth_token).and_return('token')
      settings.stub(:username).and_return(user_login)
      client = double('client')
      Octokit::Client.should_receive(:new).and_return(client)
      client.should_receive :login
      subject.login.should == user_login
    end

    it 'asks for OTP if 2FA is enabled' do
      github = ::GitReview::Provider::Github.any_instance
      github.stub :save_oauth_token
      github.stub :configure_oauth
      github.should_receive :prepare_otp
      a_count = 0
      Octokit::Client.any_instance.should_receive(:create_authorization).twice {
        # 1st attempt is OAuth without 2FA
        # if 2FA is enabled, OneTimePasswordRequired will be raised and
        # start second attempt with OTP in header.
        raise Octokit::OneTimePasswordRequired if (a_count += 1) == 1
      }
      subject.send(:authorize)
    end

  end

  context '# Pull Requests' do

    before :each do
      subject.stub(:latest_request_number).and_return(request_number)
      local.stub(:create_title_and_body).and_return([title, body])
      local.stub(:target_repo).and_return('parent:repo')
      local.stub(:head).and_return('local:repo')
      local.stub(:target_branch).and_return(target_branch)
    end

    it 'gets pull request from current source repo' do
      client.should_receive(:pull_requests).with(head_repo)
      subject.should_receive(:source_repo).and_return(head_repo)
      subject.current_requests
    end

    it 'gets pull request from provided upstream repo' do
      client.should_receive(:pull_requests).with(head_repo)
      subject.should_not_receive :source_repo
      subject.current_requests head_repo
    end

    it 'creates a request instance from the data it receives from GitHub' do
      client.should_receive(:pull_request).
        with(head_repo, request_number).and_return(request_hash)
      subject.should_receive(:source_repo).and_return(head_repo)
      subject.request(request_number).html_url.should == request_hash._links.html.href
    end

    it 'will only create a request instance if a request number is specified' do
      expect { subject.request(nil) }.
        to raise_error(GitReview::InvalidRequestIDError)
    end

    it 'determines if a certain request exists' do
      subject.should_receive(:request).with(request_number).and_return(request)
      subject.request_exists?(request_number).should be_true
    end

    it 'determines if a certain request does not exist' do
      subject.should_receive(:request).with(invalid_number).and_return(nil)
      subject.request_exists?(invalid_number).should be_false
    end

    it 'knows about a request\'s state' do
      subject.should_receive(:request).with(request_number).and_return(request)
      request.should_receive(:state).and_return('other state')
      subject.request_exists?(request_number, state).should be_false
    end

    it 'sends a pull request to the target repo' do
      new_number = request_number + 1
      subject.should_receive(:create_pull_request).
        with('parent:repo', target_branch, 'local:repo', title, body)
      subject.stub(:request_number_by_title).and_return(new_number)
      subject.should_receive(:puts).with(/Successfully/)
      subject.should_receive(:puts).with(/pull\/#{new_number}/)
      subject.send_pull_request true
    end

    it 'checks if the pull request is indeed created' do
      subject.should_receive(:create_pull_request).
        with('parent:repo', target_branch, 'local:repo', title, body)
      subject.stub(:request_number_by_title).and_return(nil)
      subject.should_receive(:puts).with(/not created for parent:repo/)
      subject.send_pull_request true
    end

  end

  context '# Repository URLs' do

    it 'constructs the remote URL for a given user name' do
      subject.should_receive(:repo_info_from_config).
        and_return([user_login, repo_name])
      subject.remote_url_for(user_login).
        should == "git@github.com:#{user_login}/#{repo_name}.git"
    end

    it 'extracts user and repo name from a given GitHub git-type URL' do
      url = 'git@github.com:foo/bar.git'
      subject.send(:url_matching, url).should == %w(foo bar)
    end

    it 'extracts user and repo name from a given GitHub HTTP URL' do
      url = 'https://github.com/foo/bar.git'
      subject.send(:url_matching, url).should == %w(foo bar)
    end

    it 'supports GitHub\'s insteadof matching for URLs' do
      url = 'git@github.com:foo/bar.git'
      config = { 'url.git@github.com:a/b.git.insteadof' => 'git@github.com:foo/bar.git' }
      subject.send(:insteadof_matching, config, url).
        should == %w(git@github.com:foo/bar.git git@github.com:a/b.git)
    end

  end

end
