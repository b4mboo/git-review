module GitReview

  class Request

    include ::GitReview::Accessible
    include ::GitReview::Deserializable
    extend ::GitReview::Nestable

    nests :head => ::GitReview::Commit,
          :base => ::GitReview::Commit,
          :user => ::GitReview::User

    attr_accessor :number,
                  :title,
                  :body,
                  :state,
                  :html_url,
                  :diff_url,
                  :patch_url,
                  :issue_url,
                  :created_at,
                  :updated_at,
                  :comments,
                  :review_comments

    def to_s
      @number
    end

    def comments_count
      @comments ||= 0
      @review_comments ||= 0
      @comments + @review_comments
    end

  end

end
