### Dependencies

## External Dependencies

# Provide access to GitHub's API.
require 'octokit'
# Open a browser in 'browse' command.
require 'launchy'
# Parse time strings from git back into Time objects.
require 'time'
# Use temporary files to allow editing a request's title and body.
require 'tempfile'

## Internal dependencies

# Include helper functions to make GitReview work as expected.
require_relative 'git-review/internals'
# Provide available commands.
require_relative 'git-review/commands'
# Read and write settings from/to the filesystem.
require_relative 'git-review/settings'
# Deal with local git repository.
require_relative 'git-review/local'
# Communicate with Github via API.
require_relative 'git-review/github'
# Include all kinds of custom-defined errors.
require_relative 'git-review/errors'

# Allow easy string colorization in the console.
require_relative 'mixins/colorizable'
# Allow to access a model's attributes in various ways (feels railsy).
require_relative 'mixins/accessible'
# Allow to nest models in other model's attributes.
require_relative 'mixins/nestable'

# Add some POROs to get some structure into the entities git-review deals with.
require_relative 'models/repository'
require_relative 'models/user'
require_relative 'models/commit'
require_relative 'models/request'
