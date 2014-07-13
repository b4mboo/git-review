class Comment < Base

  nests user: User,
        request: Request,
        commit: Commit

  attr_accessor :body,
                :updated_at,
                :created_at

end
