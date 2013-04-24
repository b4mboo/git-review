class Repository

  include Accessible
  extend Nestable

  nests :owner => User

  attr_accessor :name

end
