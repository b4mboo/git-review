module GitReview

  module Provider

    class Base

      include ::GitReview::Helpers

      attr_reader :client, :server
      attr_writer :source_repo

      def self.instance
        @instance ||= new
      end

      def initialize(server)
        @server = server
        configure_access
      end

      def connected?
        !!@client
      end

      def update
        git_call 'fetch origin'
      end

      # @return [String] Source repo name
      def source_repo
        @source_repo ||= begin
          user, repo = repo_info_from_config
          "#{user}/#{repo}"
        end
      end

      def pending_requests(repo = source_repo)
        requests(repo).reject { |request|
          local.merged? request.head.sha
        }.sort_by!(&:number)
      end

      # Determine whether a request for a specified number and state exists.
      def request_exists?(number, state = 'open', repo = source_repo)
        instance = request(number, repo)
        instance && instance.state == state
      end

      # Determine whether a request from a specified branch already exists.
      def request_exists_from_branch?(upstream = false, branch = local.source_branch)
        target_repo = local.target_repo(upstream)
        requests(target_repo).any? { |r| r.head.ref == branch }
      end

      def latest_request_number(repo = source_repo)
        server.requests(repo).collect(&:number).sort.last.to_i
      end

      # get the number of the request that matches the title
      def request_number_by_title(title, repo = source_repo)
        request = server.requests(repo).find { |r| r.title == title }
        request.number if request
      end

      def send_pull_request(to_upstream = false)
        target_repo = local.target_repo(to_upstream)
        head = server.head
        base = local.target_branch
        title, body = local.create_title_and_body(base)

        # gather information before creating pull request
        latest_number = latest_request_number(target_repo)

        # create the actual pull request
        server.create_request(target_repo, base, head, title, body)
        # switch back to target_branch and check for success
        git_call "checkout #{base}"

        # make sure the new pull request is indeed created
        new_number = request_number_by_title(title, target_repo)
        if new_number && new_number > latest_number
          puts "Successfully created new request ##{new_number}"
          puts url_for_request(target_repo, new_number)
        else
          puts "Pull request was not created for #{target_repo}."
        end
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

      # extract user and project name from repo URL.
      def url_matching(url)
        matches = /#{server.name}\.#{server.tld}.*[:|\/](.*)\/(.*)/.match(url)
        matches ? [matches[1], matches[2].sub(/\.git\z/, '')] : [nil, nil]
      end

      # look for 'insteadof' substitutions in URL.
      def insteadof_matching(config, url)
        first_match = config.keys.collect { |key|
          [
            config[key],
            /url\.(.*#{server.name}\.#{server.tld}.*)\.insteadof/.match(key)
          ]
        }.find { |insteadof_url, true_url|
          url.index(insteadof_url) and true_url != nil
        }
        first_match ? [first_match[0], first_match[1][1]] : [nil, nil]
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
