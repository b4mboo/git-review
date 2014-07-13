require 'spec_helper'

describe Comment do

  subject { Comment.new }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

  it 'has a nested attribute :user' do
    subject.user.class.should == User
  end

  it 'has a nested attribute :request' do
    subject.user.class.should == User
  end

  it 'has a nested attribute :commit' do
    subject.user.class.should == User
  end

end
