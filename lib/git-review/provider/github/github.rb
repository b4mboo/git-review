require 'net/http'
require 'net/https'
require 'yajl'
require 'io/console'
require 'stringio'
require 'socket'

module GitReview

  module Provider

    class Github < Base

      def request(number, repo = source_repo)
        raise ::GitReview::InvalidRequestIDError unless number
        Request.from_github(server, client.pull_request(repo, number))
      rescue Octokit::NotFound
        raise ::GitReview::InvalidRequestIDError
      end

      def requests(repo = source_repo)
        Request.from_github(server, client.pull_requests(repo))
      end

      def request_comments(number, repo = source_repo)
        (
          Comment.from_github(server, client.issue_comments(repo, number)) +
          Comment.from_github(server, client.review_comments(repo, number))
        ).sort_by(&:created_at)
      end

      def commits(number, repo = source_repo)
        Commit.from_github(server, client.pull_commits(repo, number))
      end

      def commit_comments(sha, repo = source_repo)
        Comment.from_github(server, client.commit_comments(repo, sha))
      end

      def url_for_request(repo, number)
        "https://github.com/#{repo}/pull/#{number}"
      end

      def url_for_remote(repo)
        "git@github.com:#{repo}.git"
      end


      private

      # extract user and project name from GitHub URL.
      def url_matching(url)
        matches = /github\.com.(.*?)\/(.*)/.match(url)
        matches ? [matches[1], matches[2].sub(/\.git\z/, '')] : [nil, nil]
      end

      # look for 'insteadof' substitutions in URL.
      def insteadof_matching(config, url)
        first_match = config.keys.collect { |key|
          [config[key], /url\.(.*github\.com.*)\.insteadof/.match(key)]
        }.find { |insteadof_url, true_url|
          url.index(insteadof_url) and true_url != nil
        }
        first_match ? [first_match[0], first_match[1][1]] : [nil, nil]
      end

      # @return [String] Authenticated username
      def configure_access
        configure_oauth unless settings.oauth_token && settings.username
        @client = Octokit::Client.new(
          login: settings.username,
          access_token: settings.oauth_token,
          auto_traversal: true
        )
        @client.login
      end

      def configure_oauth
        begin
          print_auth_message
          prepare_username unless github_login
          prepare_password
          prepare_description
          authorize!
        rescue Octokit::Unauthorized => e
          warn e.message
        rescue ::GitReview::UnprocessableState => e
          warn e.message
          exit 1
        end
      end

      def github_login
        login = git_call 'config github.user'
        @username = login.chomp if login && !login.empty?
      end

      def print_auth_message
        puts 'Requesting an OAuth token for git-review.'
        puts 'This procedure will grant access to your repositories.'
        puts 'You can revoke this authorization by visiting the following page:'
        puts 'https://github.com/settings/applications'
      end

      def prepare_username
        print 'Please enter your GitHub username: '
        @username = STDIN.gets.chomp
      end

      def prepare_password
        print "Please enter your GitHub password for #{@username} "\
        '(it won\'t be stored anywhere): '
        @password = STDIN.noecho(&:gets).chomp
      end

      def prepare_otp
        print 'Please enter your One-Time-Password for GitHub\'s 2FA: '
        @otp = STDIN.noecho(&:gets).chomp
      end

      def prepare_description
        @description = "git-review - #{Socket.gethostname}"
        puts 'Please enter a description to associate to this token.'
        puts 'It will make it easier to identify it on GitHub.'
        puts 'Press enter to continue with the proposed description.'
        print "Description [#{@description}]:"
        user_input = STDIN.gets.chomp
        @description = user_input unless user_input.empty?
      end

      def request_oauth_token(client)
        options = { :scopes => %w(repo), :note => @description }
        options.merge!(:headers => { 'X-GitHub-OTP' => @otp }) if @otp
        client.create_authorization options
      end

      def save_oauth_token(auth)
        settings.oauth_token = auth.token
        settings.username = @username
        settings.save!
        puts 'OAuth token successfully created.'
      end

      def authorize!
        begin
          auth = request_oauth_token(
            Octokit::Client.new(:login => @username, :password => @password)
          )
        rescue Octokit::OneTimePasswordRequired
          prepare_otp
          retry
        end
        save_oauth_token(auth)
      end

    end

  end

end
