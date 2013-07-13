# Provide access to GitHub's API.
require 'octokit'
# Open a browser in 'browse' command.
require 'launchy'
# Parse time strings from git back into Time objects.
require 'time'
# Use temporary files to allow editing a request's title and body.
require 'tempfile'
# Handle local git commands
require 'grit'


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

  class GitReview

    include Internals

    def initialize(args=[])
      ::GitReview::Commands.args = args
      command = args.shift
      if command.nil? || command.empty? || %w(help -h --help).include?(command)
        help
      elsif ::GitReview::Commands.respond_to?(command)
        execute_command(command)
      else
        puts "git-review: '#{command}' is not a valid command.\n\n"
        help
      end
    rescue Exception => e
      puts e.message
    end

    def help
      ::GitReview::Commands.help
    end

  private

    # execute command only when it is valid
    def execute_command(command)
      github = ::GitReview::Github.instance
      github.configure_github_access
      if github.source_repo && github.github.login
        ::GitReview::Commands.send(command)
      end
    end

  end

end
