require 'spec_helper'

describe Request do

  subject { Request.new }
  let(:default_string) { 'foo' }
  let(:changed_string) { 'bar' }

  it 'reads instance variables from a hash with symbols as keys' do
    subject.title = default_string
    subject[:title].should == default_string
  end

  it 'reads instance variables from a hash with strings as keys' do
    subject.title = default_string
    subject['title'].should == default_string
  end

  it 'sets instance variables from a hash with symbols as keys' do
    subject[:title] = changed_string
    subject.title.should == changed_string
  end

  it 'sets instance variables from a hash with strings as keys' do
    subject['title'] = changed_string
    subject.title.should == changed_string
  end

  it 'initializes instances variables with provided defaults' do
    request = Request.new(
      :title => default_string,
      :head =>
        { :sha => changed_string }
    )
    request.title.should == default_string
    request.head.sha.should == changed_string
  end

end
