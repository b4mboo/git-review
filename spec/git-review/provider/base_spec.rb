require_relative '../../spec_helper'

describe 'Provider base' do

  include_context 'request_context'

  let(:server) { mock 'server' }
  let(:local) { mock 'local' }

  before(:each) do
    subject.stub(:local).and_return(local)
  end

  subject do
    ::GitReview::Provider::Base.any_instance.stub :configure_access
    ::GitReview::Provider::Base.new server
  end


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

end
