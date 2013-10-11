require_relative '../../spec_helper'

describe 'Provider: Github' do

  subject { ::GitReview::Provider::Github }

  let(:settings) { ::GitReview::Settings.any_instance }

  before(:each) do
    settings.stub(:oauth_token).and_return('token')
    settings.stub(:username).and_return('username')
  end

  it 'constructs the remote url from a given repo name' do
    user = 'user'
    repo = 'repo'
    subject.any_instance.should_receive(:repo_info_from_config).and_return([user, repo])
    subject.new.remote_url_for(user).should == "git@github.com:#{user}/#{repo}.git"
  end

  context 'when access is not configured' do

    it 'only authenticates once' do
      subject.any_instance.should_not_receive(:configure_oauth)
      subject.new.configure_access
    end

  end

  context 'when access is configured' do

    subject { ::GitReview::Provider::Github.new }

    it 'should return a login' do
      subject.login.should eq 'username'
    end

    describe '#url_matching' do

      it 'extracts info from git url' do
        url = 'git@github.com:foo/bar.git'
        subject.send(:url_matching, url).should == %w(foo bar)
      end

      it 'extracts info from http url' do
        url = 'https://github.com/foo/bar.git'
        subject.send(:url_matching, url).should == %w(foo bar)
      end

    end

    describe '#insteadof_matching' do

      it 'from insteadof url' do
        url = 'git@github.com:foo/bar.git'
        config = { 'url.git@github.com:a/b.git.insteadof' => 'git@github.com:foo/bar.git' }
        subject.send(:insteadof_matching, config, url).should eq %w(git@github.com:foo/bar.git git@github.com:a/b.git)
      end

    end

  end

  describe '#current_requests' do

    subject { ::GitReview::Provider::Github.new }

    context 'when inquiring upstream repo' do

      let(:repo) { 'foo/bar' }

      it 'gets pull request from provided upstream repo' do
        Octokit::Client.any_instance.should_receive(:pull_requests).with(repo)
        subject.should_not_receive(:source_repo)
        subject.current_requests(repo)
      end

    end

    context 'when inquiring current repo' do

      let(:repo) { 'foo/bar' }

      it 'gets pull request from current source repo' do
        Octokit::Client.any_instance.should_receive(:pull_requests).with(repo)
        subject.stub(:source_repo).and_return(repo)
        subject.current_requests
      end

    end

  end

  describe '#create_pull_request' do

    subject { ::GitReview::Provider::Github.new }
    let(:local) { ::GitReview::Local.any_instance }

    before(:each) do
      subject.stub(:latest_request_number).and_return(1)
      local.stub(:create_title_and_body).and_return(['title', 'body'])
      local.stub(:target_repo).and_return('parent:repo')
      local.stub(:head).and_return('local:repo')
      local.stub(:target_branch).and_return('master')
      subject.stub(:git_call)
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
