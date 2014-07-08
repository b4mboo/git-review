require 'spec_helper'

describe 'Time helper' do

  subject { Time.parse('2013-10-10T09:49:38Z') }

  context '#review_time' do

    it 'should return a formatted time' do
      subject.review_time.should eq '10-Oct-13'
    end

  end

  context '#review_ljust' do

    subject { Time.parse('2013-10-10T09:49:38Z').review_ljust(30) }

    it 'should have a fixed length' do
      subject.length.should eq 30
    end

    it 'should be filled with spaces' do
      subject.count(' ').should eq 9
    end

  end

end
