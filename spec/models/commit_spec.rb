require 'spec_helper'

describe Commit do

  subject { Commit.new }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

  it 'has a nested attribute :user' do
    subject.user.class.should == User
  end

end
