require 'spec_helper'

describe Request do

  include_context 'request_context'

  subject { request }

  let(:server) { ::GitReview::Server.any_instance }

  before :each do
    ::GitReview::Provider::Github.any_instance.stub :configure_oauth
  end

  it 'has accessible attributes' do
    subject.should be_accessible
  end

  it 'has a nested attribute :head' do
    subject.head.class.should == Commit
  end

  it 'builds a one-line summary' do
    subject.summary.should include(request_number.to_s)
  end

  it 'collects all relevant details ' do
    subject.details.should include(body)
  end

  it 'collects its discussions' do
    server.should_receive(:request_comments).and_return([])
    server.should_receive(:commits).and_return([])
    subject.discussion.should include('Progress')
  end

  it 'constructs a warning about a missing source repo' do
    subject.missing_repo_warning.should include("curl #{subject.patch_url}")
  end

end
