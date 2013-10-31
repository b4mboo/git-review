class Commit

  include Accessible
  extend Nestable

  nests user: User,
        repo: Repository

  attr_accessor :sha,
                :ref,
                :label

end
