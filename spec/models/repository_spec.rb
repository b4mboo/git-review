require_relative '../spec_helper'

describe 'Repository' do

  subject { ::GitReview::Repository.new }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

end
