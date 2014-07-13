class Commit < Base

  nests user: User,
        repo: Repository

  attr_accessor :sha,
                :ref,
                :label,
                :comment_count

end
