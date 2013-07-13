require_relative '../spec_helper'

describe 'Request' do

  subject { ::GitReview::Request.new }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

  it 'has a nested attribute :head' do
    subject.head.class.should == ::GitReview::Commit
  end

end
