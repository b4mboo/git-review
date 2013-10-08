class Commit

  include Accessible
  extend Nestable

  nests user: User,
        repository: Repository

  attr_accessor :sha,
                :ref,
                :label,
                :repo

end
