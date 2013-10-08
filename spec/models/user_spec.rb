require 'spec_helper'

describe User do

  subject { User.new }

  it 'has accessible attributes' do
    subject.should be_accessible
  end

end
