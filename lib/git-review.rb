## External dependencies

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

# Allow indifferent access to attributes.
require_relative 'mixins/accessible'
# Allow nested instances.
require_relative 'mixins/nestable'
# Allow update attributes from Hashie::Mash returned by Octokit
require_relative 'mixins/deserializable'

# Read and write settings from/to the filesystem.
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

module GitReview

  class GitReview

    include Internals

    def initialize(args=[])
      @github = Github.instance
      @args = args
      command = args.shift
      if command.nil? || command.empty? || %w(help -h --help).include?(command)
        ::GitReview::Commands::help
      elsif ::GitReview::Commands.respond_to?(command)
        if local_repo_ready && github_access_ready
          @github.update unless command == 'clean'
          ::GitReview::Commands.send(command)
        end
      else
        puts "git-review: '#{command}' is not a valid command.\n\n"
        ::GitReview::Commands::help
      end
    rescue Exception => e
      puts e.message
    end

  private

    def local_repo_ready
      @github.initialize_local_repo
      @github.local_repo && @github.configure_github_access
    end

    def github_access_ready
      @github.configure_github_access
    end

  end

end
