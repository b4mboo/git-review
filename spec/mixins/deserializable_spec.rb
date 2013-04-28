require 'spec_helper'
require 'hashie'

describe 'Deserializable module' do

  class Foo
    include Deserializable
    attr_accessor :foo1, :foo2
  end

  class Baz
    extend Nestable
    include Accessible
    include Deserializable
    nests :foo => Foo
    attr_accessor :baz1, :baz2
  end

  mash = Hashie::Mash.new(
    :baz1 => 'baz1',
    :baz2 => 'baz2',
    :foo  => Hashie::Mash.new(:foo1 => 'foo1', :foo2 => 'foo2')
  )

  subject { Baz.new.update_from_mash(mash) }

  it 'updates attributes of an instance' do
    subject.baz1.should == 'baz1'
    subject.baz2.should == 'baz2'
  end

  it "recursively updates attributes of an instance's attributes" do
    subject.foo.foo1.should == 'foo1'
    subject.foo.foo2.should == 'foo2'
  end

end
