require 'spec_helper'
require 'hashie'

describe 'Deserializable module' do

  class DS_C
    include Accessible
    include Deserializable
    attr_accessor :moo1
  end

  class DS_B
    extend Nestable
    include Accessible
    include Deserializable
    nests :moo => DS_C
    attr_accessor :foo1
  end

  class DS_A
    extend Nestable
    include Accessible
    include Deserializable
    nests :foo => DS_B
    attr_accessor :baz1, :baz2
  end

  mash = Hashie::Mash.new(
    :baz1 => 'baz1',
    :baz2 => 'baz2',
    :foo  => Hashie::Mash.new(:foo1 => 'foo1',
                              :moo => Hashie::Mash.new(:moo1 => 'moo1'))
  )

  subject { DS_A.new.update_from_mash(mash) }

  it 'updates attributes of an instance' do
    subject.baz1.should == 'baz1'
    subject.baz2.should == 'baz2'
  end

  it "recursively updates attributes of an instance's attributes" do
    subject.foo.foo1.should == 'foo1'
    subject.foo.moo.moo1.should == 'moo1'
  end

  it 'returns same class after updates' do
    subject.class.should == DS_A
    subject.foo.class.should == DS_B
    subject.foo.moo.class.should == DS_C
  end

end
