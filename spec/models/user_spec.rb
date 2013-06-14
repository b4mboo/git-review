require_relative '../spec_helper'

describe 'User' do

  subject { ::GitReview::User.new }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

end
