module GitReview

  class Server

    include ::GitReview::Internals

    attr_reader :provider

    def self.instance
      @instance ||= new.provider
    end

    def initialize
      init_provider
    end

    private

    def init_provider
      @provider = case
      when bitbucket_provider?
        GitReview::Bitbucket.new
      when github_provider?
        GitReview::Github.new
      else
        raise InvalidGitProviderError.new
      end
    end

    def github_provider?
      fetch_origin_url =~ %r(github)
    end

    def bitbucket_provider?
      fetch_origin_url =~ %r(bitbucket)
    end

    def fetch_origin_url
      git_call(remote_origin_command)
    end

    def remote_origin_command
      "config --get remote.origin.url"
    end

  end

end
