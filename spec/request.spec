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
    request = Request.new(:title => default_string, 'sha' => changed_string)
    request.title.should == default_string
    request.sha.should == changed_string
  end

  it 'flattens access to \'head\' attributes' do
    subject.head.should == subject
    subject.sha = default_string
    subject.head.sha.should == default_string
    subject['head'].sha.should == default_string
    subject.head['sha'] == default_string
    subject[:head]['sha'] == default_string
  end

end
