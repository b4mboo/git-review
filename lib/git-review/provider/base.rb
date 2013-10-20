module GitReview

  module Provider

    class Base

      attr_reader :client, :server
      attr_writer :source_repo

      def self.instance
        @instance ||= new
      end

      def initialize(server)
        @server = server
        configure_access
      end

      def update
        git_call('fetch origin')
      end

      # @return [String] Source repo name
      def source_repo
        @source_repo ||= begin
          user, repo = repo_info_from_config
          "#{user}/#{repo}"
        end
      end

      # @return [String] Current username
      def login
        settings.username
      end

      # @return [Array(String, String)] User and repo name from git
      def repo_info_from_config
        url = local.config['remote.origin.url']
        raise ::GitReview::InvalidGitRepositoryError if url.nil?

        user, project = url_matching(url)

        unless user && project
          insteadof_url, true_url = insteadof_matching(local.config, url)

          if insteadof_url and true_url
            url = url.sub(insteadof_url, true_url)
            user, project = url_matching(url)
          end
        end

        [user, project]
      end

      def method_missing(method, *args)
        if client.respond_to?(method)
          client.send(method, *args)
        else
          super
        end
      end

      def respond_to?(method)
        client.respond_to?(method) || super
      end

      private

      def local
        @local ||= ::GitReview::Local.instance
      end

      def settings
        @settings ||= ::GitReview::Settings.instance
      end

    end

  end

end
