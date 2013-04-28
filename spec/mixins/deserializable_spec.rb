require 'spec_helper'
require 'hashie'

describe 'Deserializable module' do

  class Moo
    include Accessible
    include Deserializable
    attr_accessor :moo1
  end

  class Foo
    extend Nestable
    include Accessible
    include Deserializable
    nests :moo => Moo
    attr_accessor :foo1
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
    :foo  => Hashie::Mash.new(:foo1 => 'foo1',
                              :moo => Hashie::Mash.new(:moo1 => 'moo1'))
  )

  subject { Baz.new.update_from_mash(mash) }

  it 'updates attributes of an instance' do
    subject.baz1.should == 'baz1'
    subject.baz2.should == 'baz2'
  end

  it "recursively updates attributes of an instance's attributes" do
    subject.foo.foo1.should == 'foo1'
    subject.foo.moo.moo1.should == 'moo1'
  end

  it 'returns same class after updates' do
    subject.class.should == Baz
    subject.foo.class.should == Foo
    subject.foo.moo.class.should == Moo
  end

end
