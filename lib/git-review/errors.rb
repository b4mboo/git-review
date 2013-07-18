module GitReview

  class AuthenticationError < StandardError
    def message
      "You provided the wrong username/password, please try again.\n"
    end
  end

  class InvalidGitRepositoryError < StandardError
    def message
      "It is not a valid git repository or doesn't have a valid remote url."
    end
  end

  # A custom error to raise, if we know we can't go on.
  class UnprocessableState < StandardError
    def message
      'Execution of git-review stopped.'
    end
  end

  class InvalidArgumentError < StandardError
    def message
      'Please specify valid arguments. See --help for more information.'
    end
  end

  class InvalidRequestIDError < StandardError
    def message
      'Please specify a valid request ID.'
    end
  end

end