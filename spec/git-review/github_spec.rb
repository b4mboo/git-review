require_relative '../spec_helper'

describe 'Github' do

  subject { ::GitReview::Github.new }

  context '#configure_access' do

    subject { ::GitReview::Github }
    let(:settings) { ::GitReview::Settings.any_instance }

    it 'only authenticates once' do
      settings.stub(:oauth_token).and_return('token')
      settings.stub(:username).and_return('username')
      subject.any_instance.should_not_receive(:configure_oauth)
      subject.new.configure_access
    end

  end

  context 'when access is configured' do

    let(:settings) { ::GitReview::Settings.any_instance }
    let(:username) { 'foobar' }

    before(:each) do
      ::GitReview::Github.any_instance.stub(:configure_access).
        and_return('username')
    end

    it 'should return a login' do
      settings.stub(:username).and_return(username)
      subject.login.should be username
    end

    describe '#url_matching' do

      it 'extracts info from git url' do
        url = 'git@github.com:xystushi/git-review.git'
        subject.send(:url_matching, url).should == %w(xystushi git-review)
      end

      it 'extracts info from http url' do
        url = 'https://github.com/xystushi/git-review.git'
        subject.send(:url_matching, url).should == %w(xystushi git-review)
      end

    end

    describe '#insteadof_matching' do

      it 'from insteadof url' do
        url = 'git@github.com:foo/bar.git'
        config = {
          'url.git@github.com:a/b.git.insteadof' => 'git@github.com:foo/bar.git'
        }
        subject.send(:insteadof_matching, config, url).
            should == %w(git@github.com:foo/bar.git git@github.com:a/b.git)
      end

    end

  end

  context '#current_requests' do

    before(:each) do
      ::GitReview::Settings.any_instance.stub(:oauth_token).and_return('token')
      ::GitReview::Settings.any_instance.stub(:username).and_return('login')
    end

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
        subject.stub(:source_repo).and_return(repo)
        Octokit::Client.any_instance.should_receive(:pull_requests).with(repo)
        subject.current_requests
      end

    end

  end

  it 'constructs the remote url from a given repo name' do
    repo_name = 'user/repo'
    subject.remote_url_for(repo_name).should == "git@github.com:#{repo_name}.git"
  end

end
