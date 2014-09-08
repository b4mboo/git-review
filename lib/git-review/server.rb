module GitReview

  class Server

    extend Forwardable
    include ::GitReview::Helpers

    attr_reader :provider

    def self.instance
      @instance ||= new
    end

    def initialize
      init_provider
    end

    def method_missing(method, *args)
      if provider.respond_to?(method)
        provider.send(method, *args)
      else
        super
      end
    end

    def respond_to?(method)
      provider.respond_to?(method) || super
    end


    private

    def init_provider
      @provider = case
      when bitbucket_provider?
        GitReview::Provider::Bitbucket.new self
      when github_provider?
        GitReview::Provider::Github.new self
      when gitlab_provider?
        GitReview::Provider::Gitlab.new self
      else
        raise ::GitReview::InvalidGitProviderError
      end
    end

    def github_provider?
      origin_url =~ %r(github)
    end

    def bitbucket_provider?
      origin_url =~ %r(bitbucket)
    end

    def gitlab_provider?
      origin_url =~ %r(gitlab)
    end

    def origin_url
      git_call 'config --get remote.origin.url'
    end

  end

end
