module GitReview

  class User

    include ::GitReview::Accessible
    include ::GitReview::Deserializable

    attr_accessor :login

    def to_s
      @login
    end

    def repos
      ::GitReview::Github.instance.repositories(@login)
    end

  end

end