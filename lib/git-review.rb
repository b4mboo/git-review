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
require_relative 'mixins/authenticable'
# Allow indifferent access to attributes.
require_relative 'mixins/accessible'
# Allow nested instances.
require_relative 'mixins/nestable'
# Allow update attributes from Hashie::Mash returned by Octokit
require_relative 'mixins/deserializable'

# Read and write settings from/to the filesytem.
require_relative 'base/settings'
# Provide available commands.
require_relative 'base/commands'
# Include all helper functions to make GitReview work as expected.
require_relative 'base/internals'
# Include all kinds of custom-defined errors.
require_relative 'base/errors'
# Communicate with Github via API.
require_relative 'base/github'

# Provide structure for our instances.
require_relative 'models/user'
require_relative 'models/repository'
require_relative 'models/commit'
require_relative 'models/request'
require_relative 'models/comment'


class GitReview

  include Authenticable
  include Commands
  include Internals

end
