class Repository

  include Accessible
  extend Nestable

  nests :owner => User

  attr_accessor :name,
                :full_name

end
