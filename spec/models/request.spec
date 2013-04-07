require 'spec_helper'

describe Request do

  subject { Request.new }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

  it 'has a nested attribute :head' do
    subject.head.class.should == Commit
  end

end
