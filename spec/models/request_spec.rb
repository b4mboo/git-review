require 'spec_helper'

describe Request do

  include_context 'request_context'

  subject { request }

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
    subject.server.should_receive(:comments_count).and_return(0)
    subject.summary.should include(request_number.to_s)
  end

  it 'collects all relevant details ' do
    subject.server.should_receive(:comments_count).and_return(0)
    subject.details.should include(body)
  end

  it 'collects its discussions' do
    subject.server.should_receive(:discussion).
      with(request_number).and_return('')
    subject.discussion.should include('Progress')
  end

  it 'constructs a warning about a missing source repo' do
    subject.missing_repo_warning.should include("curl #{subject.patch_url}")
  end

end
