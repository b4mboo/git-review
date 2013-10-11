module GitReview

  module Provider

    class Bitbucket < Base

      # @return [String] Authenticated username
      def configure_access
        if settings.bitbucket_oauth_token && settings.bitbucket_username
          #@client = Octokit::Client.new(
          #  login: settings.github_username,
          #  access_token: settings.github_oauth_token,
          #  auto_traversal: true
          #)

          #@client.login
        else
          configure_oauth
          configure_access
        end
      end

      # a default collection of requests
      def current_requests(repo = source_repo)
        #client.pull_requests(repo)
      end

      # a detailed collection of requests
      def detailed_requests(repo = source_repo)
        #threads = []
        #requests = []

        #client.pull_requests(repo).each do |req|
        #  threads << Thread.new {
        #    requests << client.pull_request(repo, req.number)
        #  }
        #end

        #threads.each { |t| t.join }
        #requests
      end








      # @return [String] SSH url for bitbucket
      def remote_url_for(user_name)
        "git@bitbucket.org:#{user_name}/#{repo_info_from_config.last}.git"
      end

      # @return [String] Current username
      def login
        settings.bitbucket_username
      end

      private

      def authorize
        uri = URI(sprintf('https://bitbucket.org/api/1.0/users/%s/consumers', @username))

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        req = Net::HTTP::Post.new(uri.request_uri)
        req.basic_auth(@username, @password)

        req.body = URI.encode(sprintf(
          "name=%s&description=%s",
          'git-review',
          @description
        ))

        response = http.request(req)

        if response.code == '201'
          parser_response = Yajl::Parser.parse(response.body)
          save_oauth_token(parser_response['secret'])
        elsif response.code == '401'
          raise ::GitReview::AuthenticationError
        else
          raise ::GitReview::UnprocessableState, response.body
        end
      end

      def prepare_username_and_password
        puts "Requesting a OAuth token, this procedure will grant access to your public and private repositories."
        puts "You can revoke this authorization by visiting the following page: https://bitbucket.org/account/user/USERNAME/api"

        print "Please enter your Bitbucket username: "
        @username = STDIN.gets.chomp

        print "Please enter your Bitbucket password: "
        @password = STDIN.noecho(&:gets).chomp

        print "\n"
      end

      def save_oauth_token(token)
        settings = ::GitReview::Settings.instance

        settings.bitbucket_oauth_token = token
        settings.bitbucket_username = @username
        settings.save!

        puts "OAuth token successfully created.\n"
      end

      def url_matching(url)
        matches = /bitbucket\.org.(.*?)\/(.*)/.match(url)
        matches ? [matches[1], matches[2].sub(/\.git\z/, '')] : [nil, nil]
      end

      def insteadof_matching(config, url)
        first_match = config.keys.collect { |key|
          [config[key], /url\.(.*bitbucket\.org.*)\.insteadof/.match(key)]
        }.find { |insteadof_url, true_url|
          url.index(insteadof_url) and true_url != nil
        }

        first_match ? [first_match[0], first_match[1][1]] : [nil, nil]
      end

    end

  end

end
