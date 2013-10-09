module GitReview

  class Server

    extend Forwardable
    include ::GitReview::Internals

    attr_reader :provider

    def_delegators(
      :provider,
      :configure_access,
      :request_url_for,
      :create_pull_request,
      :source_repo,
      :current_requests_full,
      :request_exists?,
      :source_repo,
      :add_comment,
      :close_issue,
      :request_exists_for_branch?,
      :repository,
      :latest_request_number,
      :request_number_by_title
    )

    def self.instance
      @instance ||= new
    end

    def initialize
      init_provider
    end

    private

    def init_provider
      @provider = case
      when bitbucket_provider?
        GitReview::Provider::Bitbucket.new
      when github_provider?
        GitReview::Provider::Github.new
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
