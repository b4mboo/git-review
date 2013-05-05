module Errors

  class AuthenticationError < StandardError
    def message
      "You provided the wrong username/password, please try again.\n"
    end
  end

  # A custom error to raise, if we know we can't go on.
  class UnprocessableState < StandardError
  end

end
