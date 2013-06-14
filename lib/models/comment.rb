module GitReview

  class Comment

    include ::GitReview::Accessible
    include ::GitReview::Deserializable
    extend ::GitReview::Nestable

    nests :user => ::GitReview::User

    attr_accessor :id,
                  :body,
                  :created_at,
                  :updated_at

    def to_s
      @body
    end

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

end