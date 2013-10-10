require 'spec_helper'

describe 'Accessible module' do

  class Foo
    include Accessible
    attr_accessor :bar, :baz
  end

  class Baz
    include Accessible
    attr_accessor :berk
  end

  subject { Foo.new }
  let(:test_string) { 'foo' }

  it 'is self conscious about being accessible' do
    subject.should be_accessible
  end

  it 'initializes instances variables with provided defaults' do
    subject = Foo.new(bar: test_string,)
    subject.bar.should == test_string
  end

  it 'reads instance variables from a hash with symbols as keys' do
    subject.bar = test_string
    subject[:bar].should == test_string
  end

  it 'reads instance variables from a hash with strings as keys' do
    subject.bar = test_string
    subject['bar'].should == test_string
  end

  it 'sets instance variables from a hash with symbols as keys' do
    subject[:bar] = test_string
    subject.bar.should == test_string
  end

  it 'sets instance variables from a hash with strings as keys' do
    subject['bar'] = test_string
    subject.bar.should == test_string
  end

  it 'sets attributes from a hash' do
    subject.update_attributes bar: test_string, baz: test_string
    subject.bar.should == test_string
    subject.baz.should == test_string
  end

  it 'recursively sets nested accessible attributes' do
    subject.baz = Baz.new
    subject.update_attributes(
      bar: test_string,
      baz: { berk: test_string }
    )
    subject.baz.class.should == Baz
    subject.baz.berk.should == test_string
  end

end
