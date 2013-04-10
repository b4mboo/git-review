## External dependencies

# Provide access to GitHub's API.
require 'octokit'
# Open a browser in 'browse' command.
require 'launchy'
# Parse time strings from git back into Time objects.
require 'time'
# Use temporary files to allow editing a request's title and body.
require 'tempfile'


## Our own dependencies

# Use oauth tokens for authentication with GitHub.
require 'mixins/authenticable'
# Allow indifferent access to attributes.
require 'mixins/accessible'
# Allow nested instances.
require 'mixins/nestable'

# Read and write settings from/to the filesytem.
require 'base/settings'
# Provide available commands.
require 'base/commands'
# Include all helper functions to make GitReview work as expected.
require 'base/internals'

# Provide structure for our instances.
require 'models/user'
require 'models/repository'
require 'models/commit'
require 'models/request'


# A custom error to raise, if we know we can't go on.
class UnprocessableState < StandardError
end


class GitReview

  include Authenticable
  include Commands
  include Internals

end
