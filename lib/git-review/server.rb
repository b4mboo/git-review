module GitReview

  class Server

    extend Forwardable
    include ::GitReview::Internals

    attr_reader :provider

    def_delegators(
      :provider,

      :configure_access,
      :request_exists?,
      :request_exists_for_branch?,
      :current_requests,
      :current_requests_full,
      :update,
      :repo_info_from_config,
      :source_repo,
      :commit_discussion,
      :issue_discussion,
      :comments_count,
      :discussion,
      :latest_request_number,
      :request_number_by_title,
      :login,
      :request_url_for,
      :create_pull_request,
      :add_comment,
      :close_issue,
      :repository
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
      git_call(call_origin_params)
    end

    def call_origin_params
      "config --get remote.origin.url"
    end

  end

end
