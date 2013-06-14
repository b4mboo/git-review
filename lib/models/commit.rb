module GitReview

  class Commit

    include ::GitReview::Accessible
    include ::GitReview::Deserializable
    extend ::GitReview::Nestable

    nests :user => ::GitReview::User,
          :repo => ::GitReview::Repository

    attr_accessor :sha,
                  :ref,
                  :label

    def to_s
      @sha
    end

  end

end