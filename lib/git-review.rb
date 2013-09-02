# Provide access to GitHub's API.
require 'octokit'
# Open a browser in 'browse' command.
require 'launchy'
# Parse time strings from git back into Time objects.
require 'time'
# Use temporary files to allow editing a request's title and body.
require 'tempfile'

## Our own dependencies

# Include all helper functions to make GitReview work as expected.
require_relative 'git-review/internals'
# Deal with current git repository.
require_relative 'git-review/local'
# Communicate with Github via API.
require_relative 'git-review/github'
# Read and write settings from/to the filesystem.
require_relative 'git-review/settings'
# Provide available commands.
require_relative 'git-review/commands'
# Include all kinds of custom-defined errors.
require_relative 'git-review/errors'


module GitReview

end
