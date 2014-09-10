require_relative '../../../spec_helper'

describe 'Provider: Bitbucket' do

  include_context 'request_context'

  subject { ::GitReview::Provider::Bitbucket.new(server) }

  let(:server) { double 'server' }
  let(:client) { double 'client' }
  let(:settings) { double 'settings' }

  before :each do
    Bucketkit::Client.stub(:new).and_return(client)
    ::GitReview::Settings.stub(:instance).and_return(settings)
    settings.stub(:bitbucket_consumer_key).and_return('CONSUMER_KEY')
    settings.stub(:bitbucket_consumer_secret).and_return('CONSUMER_SECRET')
    settings.stub(:bitbucket_token).and_return('TOKEN')
    settings.stub(:bitbucket_token_secret).and_return('TOKEN_SECRET')
    settings.stub(:bitbucket_username).and_return(user_login)
    client.stub :login
    subject.stub :puts
    subject.stub :print
  end

  context '# Authentication' do

    it 'configures access to bitbucket' do
      ::GitReview::Provider::Bitbucket.any_instance.should_receive :configure_access
      ::GitReview::Provider::Bitbucket.new server
    end

    it 'uses Bucketkit to login to Bitbucket' do
      ::GitReview::Provider::Bitbucket.any_instance
      Bucketkit::Client.should_receive(:new).and_return(client)
      client.should_receive :login
      ::GitReview::Provider::Bitbucket.new(server).login.should == user_login
    end

    it 'uses oauth token for authentication' do
      subject.should_receive(:authenticated?).and_return(false)
      subject.should_receive(:configure_oauth).and_return(nil)
      subject.send :configure_access
    end

    it 'asks for credentials when accessing Bitbucket for the first time' do
      subject.stub(:print_auth_message)
      subject.stub(:prepare_description)
      subject.should_receive(:prepare_username)
      subject.should_receive(:prepare_password)
      subject.should_receive(:authorize!)
      subject.send :configure_oauth
    end

  end

  context '# Request' do

    it 'closes an open request' do
      subject.stub(:source_repo).and_return(head_repo)
      client.should_receive(:merge_pull_request).
          with(head_repo, request_number).
          and_return(state: 'MERGED')
      subject.close(request_number).should match /Successfully closed request./
    end

    it 'displays error if a request is not closed' do
      message = 'fail'
      subject.stub(:source_repo).and_return(head_repo)
      client.should_receive(:merge_pull_request).
          with(head_repo, request_number).
          and_return(error: message)
      subject.close(request_number).should match /Failed to close request./
    end

    it 'posts an approving comment in your name to the request\'s page' do
      subject.stub(:source_repo).and_return(head_repo)
      client.should_receive(:approve_pull_request).
          with(head_repo, request_number).and_return(approved: true)
      subject.approve(request_number).should match /Successfully approved request./
    end

    it 'outputs any errors that might occur when trying to post a comment' do
      message = 'fail'
      subject.stub(:source_repo).and_return(head_repo)
      client.should_receive(:approve_pull_request).
          with(head_repo, request_number).
          and_return(error: {message: message})
      subject.approve(request_number).should match message
    end

    it 'has correct head format' do
      ::GitReview::Local.any_instance.should_not_receive(:source_repo)
      ::GitReview::Local.any_instance.should_receive(:source_branch).
          and_return('branch')
      subject.head.should == 'branch'
    end

  end

  context '# URLs' do

    it 'constructs the remote URL for a given repo' do
      subject.url_for_remote(head_repo).
          should == "git@bitbucket.org:#{head_repo}.git"
    end

    it 'constructs the request URL for a given repo' do
      subject.url_for_request(head_repo, request_number).
          should == "https://bitbucket.org/#{head_repo}/pull-request/#{request_number}"
    end

  end

end
