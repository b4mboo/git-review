### Dependencies

## External Dependencies

# Parse time strings from git back into Time objects.
require 'time'
# Use temporary files to allow editing a request's message.
require 'tempfile'
# Open a browser in 'browse' command.
require 'launchy'
# Provide access to GitHub's API.
require 'octokit'

## Internal dependencies

require_relative 'git-review/helpers'
require_relative 'git-review/commands'
require_relative 'git-review/settings'
require_relative 'git-review/local'
require_relative 'git-review/errors'
require_relative 'git-review/server'

require_relative 'mixins/colorizable'
require_relative 'mixins/accessible'
require_relative 'mixins/nestable'

require_relative 'override/string'
require_relative 'override/time'

# Add some POROs to get some structure into the entities git-review deals with.
require_relative 'models/base'
require_relative 'models/repository'
require_relative 'models/user'
require_relative 'models/commit'
require_relative 'models/request'

# Communicate with providers and load provider specific model extensions.
# Require GH specific model extensions.
require_relative 'git-review/provider/base'
require_relative 'git-review/provider/github/github'
require_relative 'git-review/provider/github/request'
require_relative 'git-review/provider/github/commit'
require_relative 'git-review/provider/bitbucket/bitbucket'
