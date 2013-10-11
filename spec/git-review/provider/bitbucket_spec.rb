require_relative '../../spec_helper'

describe 'Provider: Bitbucket' do

  subject { ::GitReview::Provider::Bitbucket }

  let(:settings) { ::GitReview::Settings.any_instance }

  before(:each) do
    settings.stub(:bitbucket_oauth_token).and_return('token')
    settings.stub(:bitbucket_username).and_return('username')
  end

  it 'constructs the remote url from a given repo name' do
    user = 'user'
    repo = 'repo'
    subject.any_instance.should_receive(:repo_info_from_config).and_return([user, repo])
    subject.new.remote_url_for(user).should == "git@bitbucket.org:#{user}/#{repo}.git"
  end

  context 'when access is not configured' do

    it 'only authenticates once' do
      subject.any_instance.should_not_receive(:configure_oauth)
      subject.new.configure_access
    end

  end

  context 'when access is configured' do

    subject { ::GitReview::Provider::Bitbucket.new }

    it 'should return a login' do
      subject.login.should eq 'username'
    end

    describe '#url_matching' do

      it 'extracts info from git url' do
        url = 'git@bitbucket.org:foo/bar.git'
        subject.send(:url_matching, url).should == %w(foo bar)
      end

      it 'extracts info from http url' do
        url = 'https://bitbucket.org/foo/bar.git'
        subject.send(:url_matching, url).should == %w(foo bar)
      end

    end

    describe '#insteadof_matching' do

      it 'from insteadof url' do
        url = 'git@bitbucket.org:foo/bar.git'
        config = { 'url.git@bitbucket.org:a/b.git.insteadof' => 'git@bitbucket.org:foo/bar.git' }
        subject.send(:insteadof_matching, config, url).should eq %w(git@bitbucket.org:foo/bar.git git@bitbucket.org:a/b.git)
      end

    end










  end

end
