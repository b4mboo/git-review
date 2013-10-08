require 'spec_helper'

describe 'Nestable module' do

  class Foo
  end

  class Baz
    extend Nestable
    nests foo: Foo
  end

  subject { Baz.new }

  it 'creates an accessor for a nested instance' do
    subject.foo.class.should == Foo
  end

end
