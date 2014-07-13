require_relative '../../../spec_helper'

describe 'Provider: Github' do

  include_context 'request_context'

  subject { ::GitReview::Provider::Github.new(server) }

  let(:server) { double 'server' }
  let(:client) { double 'client' }
  let(:settings) { double 'settings' }

  before :each do
    Octokit::Client.stub(:new).and_return(client)
    ::GitReview::Settings.stub(:instance).and_return(settings)
    settings.stub(:oauth_token).and_return('oauth_token')
    settings.stub(:username).and_return(user_login)
    client.stub :login
  end


  context '# Authentication' do


    it 'configures access to GitHub' do
      ::GitReview::Provider::Github.any_instance.should_receive :configure_access
      ::GitReview::Provider::Github.new server
    end

    it 'uses Octokit to login to GitHub' do
      Octokit::Client.should_receive(:new).and_return(client)
      client.should_receive :login
      subject.login.should == user_login
    end

    it 'uses an oauth token for authentication' do
      subject.should_receive :configure_oauth
      settings.should_receive(:oauth_token).and_return(nil)
      subject.send :configure_access
    end

    it 'asks for One-Time-Password if 2FA is enabled' do
      subject.should_receive :save_oauth_token
      subject.should_receive :prepare_otp
      client = double 'client'
      Octokit::Client.stub(:new).and_return(client)
      count = 0
      client.should_receive(:create_authorization).twice {
        # The 1st attempt is OAuth without 2FA.
        # If 2FA is enabled, OneTimePasswordRequired will be raised and
        # prepare_otp will be called before starting a 2nd attempt.
        count += 1
        raise Octokit::OneTimePasswordRequired if count == 1
      }
      subject.send :authorize!
    end

    it 'doesn\'t ask for GitHub username if it is present in the config' do
      subject.stub :print_auth_message
      subject.stub :prepare_password
      subject.stub :prepare_description
      subject.stub :authorize!
      subject.should_receive(:github_login).and_return(user_login)
      subject.send :configure_oauth
    end

  end


  context '# Requests' do

    it 'get a specified pull request from current source repo' do
      subject.should_receive(:source_repo).and_return(head_repo)
      client.should_receive(:pull_request)
        .with(head_repo, request_number).and_return([])
      subject.request request_number
    end

    it 'allows to get a specified pull request from a specified repo' do
      subject.should_not_receive :source_repo
      client.should_receive(:pull_request)
        .with(head_repo, request_number).and_return([])
      subject.request(request_number, head_repo)
    end

    it 'creates Request instances from the data it receives from GitHub' do
      client.should_receive(:pull_request).
        with(head_repo, request_number).and_return(request_hash)
      req = subject.request(request_number, head_repo)
      req.html_url.should == request_hash._links.html.href
      req.should be_a(Request)
    end

    it 'will only create a Request instance if a request number is specified' do
      expect { subject.request(nil, head_repo) }.
        to raise_error(GitReview::InvalidRequestIDError)
    end

    it 'gets pull requests from current source repo' do
      subject.should_receive(:source_repo).and_return(head_repo)
      client.should_receive(:pull_requests).with(head_repo).and_return([])
      subject.requests
    end

    it 'allows to get pull requests from a specified repo' do
      subject.should_not_receive :source_repo
      client.should_receive(:pull_requests).with(head_repo).and_return([])
      subject.requests head_repo
    end

    it 'creates Request instances from the data it receives from GitHub' do
      client.should_receive(:pull_requests).
        with(head_repo).and_return([request_hash])
      req = subject.requests(head_repo).first
      req.html_url.should == request_hash._links.html.href
      req.should be_a(Request)
    end

    it 'opens a new pull request on Gitub' do
      client.should_receive(:create_pull_request)
        .with(head_repo, branch_name, head_ref, title, body)
      subject.create_request(head_repo, branch_name, head_ref, title, body)
    end

  end


  context '# Commits' do

    include_context 'commit_context'

    it 'gets commits by default from current source repo' do
      subject.should_receive(:source_repo).and_return(head_repo)
      client.should_receive(:pull_commits)
        .with(head_repo, request_number).and_return([])
      subject.commits request_number
    end

    it 'gets commits from a specified repo' do
      subject.should_not_receive :source_repo
      client.should_receive(:pull_commits)
        .with(head_repo, request_number).and_return([])
      subject.commits(request_number, head_repo)
    end

    it 'creates Commit instances from the data it receives from GitHub' do
      client.should_receive(:pull_commits)
        .with(head_repo, request_number).and_return([commit_hash])
      com = subject.commits(request_number, head_repo).first
      com.sha.should == commit_hash.sha
      com.should be_a(Commit)
    end

  end


  context '# Comments' do

    include_context 'comment_context'

    it 'gets request comments by default from current source repo' do
      subject.should_receive(:source_repo).and_return(head_repo)
      client.should_receive(:issue_comments)
        .with(head_repo, request_number).and_return([])
      client.should_receive(:review_comments)
        .with(head_repo, request_number).and_return([])
      subject.request_comments request_number
    end

    it 'allows to get request comments from a specified repo' do
      subject.should_not_receive :source_repo
      client.should_receive(:issue_comments)
        .with(head_repo, request_number).and_return([])
      client.should_receive(:review_comments)
        .with(head_repo, request_number).and_return([])
      subject.request_comments(request_number, head_repo)
    end

    it 'creates Comment instances from the request comment data from GitHub' do
      client.should_receive(:issue_comments)
        .with(head_repo, request_number).and_return([comment_hash])
      client.should_receive(:review_comments)
        .with(head_repo, request_number).and_return([comment_hash])
      com = subject.request_comments(request_number, head_repo).first
      com.body.should == comment_hash.body
      com.should be_a(Comment)
    end

    it 'gets commit comments by default from current source repo' do
      subject.should_receive(:source_repo).and_return(head_repo)
      client.should_receive(:commit_comments)
        .with(head_repo, head_sha).and_return([])
      subject.commit_comments head_sha
    end

    it 'allows to get commit comments from a specified repo' do
      subject.should_not_receive :source_repo
      client.should_receive(:commit_comments)
        .with(head_repo, head_sha).and_return([])
      subject.commit_comments(head_sha, head_repo)
    end

    it 'creates Comment instances from the commit comment data from GitHub' do
      client.should_receive(:commit_comments)
        .with(head_repo, head_sha).and_return([comment_hash])
      com = subject.commit_comments(head_sha, head_repo).first
      com.body.should == comment_hash.body
      com.should be_a(Comment)
    end

  end


  context '# URLs' do

    it 'constructs the remote URL for a given repo' do
      subject.url_for_remote(head_repo).
        should == "git@github.com:#{head_repo}.git"
    end

    it 'constructs the request URL for a given repo' do
      subject.url_for_request(head_repo, request_number).
        should == "https://github.com/#{head_repo}/pull/#{request_number}"
    end

  end

end
