class Comment

  include Accessible
  include Deserializable
  extend Nestable

  nests :user => User

  attr_accessor :id,
                :body,
                :created_at,
                :updated_at

end

class ReviewComment < Comment

  attr_accessor :path,
                :position,
                :commit_id

end

class IssueComment < Comment

  attr_accessor :html_url

end

class CommitComment < Comment

  attr_accessor :path,
                :position,
                :line,
                :commit_id,
                :html_url

end
