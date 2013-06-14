module GitReview

  class User

    include ::GitReview::Accessible
    include ::GitReview::Deserializable

    attr_accessor :login

    def to_s
      @login
    end

  end

end