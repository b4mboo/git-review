require_relative '../spec_helper'

describe 'Github' do

  describe '#configure_github_access' do

    subject { ::GitReview::Github }
    let(:settings) { ::GitReview::Settings.any_instance }

    it 'only authenticates once' do
      settings.stub(:oauth_token).and_return('token')
      settings.stub(:username).and_return('username')
      subject.any_instance.should_not_receive(:configure_oauth)
      subject.new.configure_github_access
    end

  end

  context 'when access is configured' do

    subject { ::GitReview::Github.new }

    before(:each) do
      ::GitReview::Github.any_instance.stub(:configure_github_access).
          and_return('username')
    end

    describe '#github_url_matching' do

      it 'extracts info from git url' do
        url = 'git@github.com:xystushi/git-review.git'
        subject.send(:github_url_matching, url).should == %w(xystushi git-review)
      end

      it 'extracts info from http url' do
        url = 'https://github.com/xystushi/git-review.git'
        subject.send(:github_url_matching, url).should == %w(xystushi git-review)
      end

    end

    describe '#github_insteadof_matching' do

      it 'from insteadof url' do
        url = 'git@github.com:foo/bar.git'
        config = {
            'url.git@github.com:a/b.git.insteadof' =>
                'git@github.com:foo/bar.git'
        }
        subject.send(:github_insteadof_matching, config, url).
            should == %w(git@github.com:foo/bar.git git@github.com:a/b.git)
      end

    end

  end

  describe '#current_requests' do

    subject { ::GitReview::Github.new }

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

end
