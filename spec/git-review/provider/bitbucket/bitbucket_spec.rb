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

  end

  context '# Approvals' do

    before :each do
      subject.stub(:source_repo).and_return(head_repo)
    end

    it 'posts an approving comment in your name to the request\'s page' do
      client.should_receive(:approve_pull_request).
          with(head_repo, request_number).and_return(approved: true)
      subject.approve(request_number).should match /Successfully approved request./
    end

    it 'outputs any errors that might occur when trying to post a comment' do
      message = 'fail'
      client.should_receive(:approve_pull_request).
          with(head_repo, request_number).
          and_return(error: {message: message})
      subject.approve(request_number).should match message
    end

  end

end
