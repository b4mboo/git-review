require_relative '../../spec_helper'

describe 'Provider: Github' do

  include_context 'request_context'

  subject { ::GitReview::Provider::Github.new }

  let(:settings) { ::GitReview::Settings.any_instance }
  let(:local) { ::GitReview::Local.any_instance }

  before :each do
    settings.stub(:oauth_token).and_return('token')
    settings.stub(:username).and_return('username')
  end

  context '# Authentication' do

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

  describe '#current_requests' do

    context 'when inquiring upstream repo' do

      it 'gets pull request from provided upstream repo' do
        Octokit::Client.any_instance.should_receive(:pull_requests).with(head_repo)
        subject.should_not_receive :source_repo
        subject.current_requests head_repo
      end

    end

    context 'when inquiring current repo' do

      it 'gets pull request from current source repo' do
        Octokit::Client.any_instance.should_receive(:pull_requests).with(head_repo)
        subject.stub(:source_repo).and_return(head_repo)
        subject.current_requests
      end

    end

  end

  describe '#create_pull_request' do

    before :each do
      subject.stub(:latest_request_number).and_return(1)
      local.stub(:create_title_and_body).and_return(['title', 'body'])
      local.stub(:target_repo).and_return('parent:repo')
      local.stub(:head).and_return('local:repo')
      local.stub(:target_branch).and_return('master')
      subject.stub :git_call
    end

    it 'sends pull request to upstream repo' do
      subject.should_receive(:create_pull_request).
        with('parent:repo', 'master', 'local:repo', 'title', 'body')
      subject.stub(:request_number_by_title).and_return(2)
      subject.should_receive(:puts).with(/Successfully/)
      subject.should_receive(:puts).with(/pull\/2/)
      subject.send_pull_request true
    end

    it 'checks if pull request is indeed created' do
      subject.should_receive(:create_pull_request).
        with('parent:repo', 'master', 'local:repo', 'title', 'body')
      subject.stub(:request_number_by_title).and_return(nil)
      subject.should_receive(:puts).with(/not created for parent:repo/)
      subject.send_pull_request true
    end

  end

end
