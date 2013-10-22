require 'spec_helper'

describe Request do

  include_context 'request_context'

  subject { request }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

  it 'has a nested attribute :head' do
    subject.head.class.should == Commit
  end

  it 'builds a one-line summary' do
    subject.server.stub(:comments_count).and_return(0)
    subject.summary.should include(request_number.to_s)
  end

  it 'collects all relevant details ' do
    subject.server.stub(:comments_count).and_return(0)
    subject.details.should include(body)
  end

end
