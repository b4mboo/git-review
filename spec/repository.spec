require 'spec_helper'

describe Repository do

  subject { Repository.new }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

end
