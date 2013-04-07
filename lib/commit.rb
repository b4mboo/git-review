class Commit

  include Accessible
  extend Nestable

  nests :user => User

  attr_accessor :sha,
                :ref,
                :label,
                :repo

end
