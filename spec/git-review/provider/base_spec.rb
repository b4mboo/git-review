require_relative '../../spec_helper'

describe 'Provider base' do

  include_context 'request_context'

  before(:each) do
    ::GitReview::Server.stub(:new).and_return(server)
    ::GitReview::Provider::Base.any_instance.stub :git_call
    ::GitReview::Provider::Base.any_instance.stub :configure_access
    subject.stub(:local).and_return(local)
  end

  subject { ::GitReview::Provider::Base.new server }

  let(:server) { double 'server' }
  let(:local) { double 'local' }


  it 'determines if a certain request exists' do
    subject.should_receive(:request).with(request_number, head_repo).and_return(request)
    subject.request_exists?(request_number, 'open', head_repo).should be_true
  end

  it 'determines if a certain request does not exist' do
    subject.should_receive(:request).with(invalid_number, head_repo).and_return(nil)
    subject.should_receive(:source_repo).and_return(head_repo)
    subject.request_exists?(invalid_number).should be_false
  end

  it 'knows about a request\'s state' do
    subject.should_receive(:request).with(request_number, head_repo).and_return(request)
    subject.should_receive(:source_repo).and_return(head_repo)
    request.should_receive(:state).and_return('other state')
    subject.request_exists?(request_number, state).should be_false
  end

  it 'determines if a request for a certain branch exists' do
    local.should_receive(:target_repo).with(true).and_return(head_repo)
    subject.should_receive(:requests).with(head_repo).and_return([request])
    subject.request_exists_from_branch?(true, target_branch)
  end

  it 'sends a pull request to the target repo' do
    new_number = request_number + 1

    local.stub(:target_repo).and_return('parent:repo')
    local.stub(:head).and_return('local:repo')
    local.stub(:target_branch).and_return(target_branch)
    local.stub(:create_title_and_body).and_return([title, body])
    subject.stub(:latest_request_number).and_return(request_number)
    subject.stub(:url_for_request).and_return("url/to/pull/#{new_number}")

    server.should_receive(:create_request).
      with('parent:repo', target_branch, 'local:repo', title, body)
    subject.stub(:request_number_by_title).and_return(new_number)
    subject.should_receive(:puts).with(/Successfully/)
    subject.should_receive(:puts).with(/pull\/#{new_number}/)
    subject.send_pull_request true
  end

  it 'checks if the pull request is indeed created' do
    local.stub(:target_repo).and_return('parent:repo')
    local.stub(:head).and_return('local:repo')
    local.stub(:target_branch).and_return(target_branch)
    local.stub(:create_title_and_body).and_return([title, body])
    subject.stub(:latest_request_number).and_return(request_number)

    server.should_receive(:create_request).
      with('parent:repo', target_branch, 'local:repo', title, body)
    subject.stub(:request_number_by_title).and_return(nil)
    subject.should_receive(:puts).with(/not created for parent:repo/)
    subject.send_pull_request true
  end

  it 'determines the latest request number' do
    server.should_receive(:requests).with(head_repo).and_return([request])
    subject.latest_request_number(head_repo).should eq(request.number)
  end

  it 'finds a request\'s number by title' do
    server.should_receive(:requests).with(head_repo).and_return([request])
    subject.request_number_by_title(title, head_repo).should eq(request.number)
  end

end
