require 'grit'
require 'singleton'

module GitReview

  # The local repository is where the git-review command is being called
  # by default. It is not specific to Github.
  class Local

    include Singleton

    attr_accessor :config

    def initialize(path='.')
      repo = Grit::Repo.new(path)
      @config = repo.config
    rescue
      raise ::GitReview::Errors::InvalidGitRepositoryError
    end

  end

end
