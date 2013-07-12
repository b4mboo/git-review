module GitReview

  class Commit

    include ::GitReview::Accessible
    include ::GitReview::Deserializable
    extend ::GitReview::Nestable

    attr_accessor :sha, :message

    def to_s
      @sha
    end

  end

  class PullRequestCommit

    include ::GitReview::Accessible
    include ::GitReview::Deserializable
    extend ::GitReview::Nestable

    nests :commit => ::GitReview::Commit,
          :author => ::GitReview::User,
          :committer => ::GitReview::User

    attr_accessor :sha

    def to_s
      @sha
    end

    def message
      @commit.message
    end

  end

end