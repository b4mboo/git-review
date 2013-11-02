module GitReview

  class AuthenticationError < StandardError
    def message
      'Authentication failed. Check username/password.'
    end
  end

  class InvalidGitProviderError < StandardError
    def message
      'Invalid git provider.'
    end
  end

  class InvalidGitRepositoryError < StandardError
    def message
      'Invalid git repository or remote url.'
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
      'Invalid arguments. See --help for more information.'
    end
  end

  class InvalidRequestIDError < StandardError
    def message
      'Invalid request ID.'
    end
  end

end
