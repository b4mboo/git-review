module Errors

  class AuthenticationError < StandardError
    def message
      "You provided the wrong username/password, please try again.\n"
    end
  end

  class FatalError < StandardError
    def message(m)
      "Something went wrong: #{m}\n"
    end
  end

  # A custom error to raise, if we know we can't go on.
  class UnprocessableState < StandardError
  end

end
