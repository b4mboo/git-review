require 'grit'

module GitReview

  module Errors

    class AuthenticationError < StandardError
      def message
        "You provided the wrong username/password, please try again.\n"
      end
    end

    class InvalidGitRepositoryError < Grit::InvalidGitRepositoryError
      def message
        "It is not a valid git repository or doesn't have a valid remote url."
      end
    end

    # A custom error to raise, if we know we can't go on.
    class UnprocessableState < StandardError
      def message
        "Execution of git-review stopped."
      end
    end

    class InvalidArgumentError < StandardError

    end

  end

end