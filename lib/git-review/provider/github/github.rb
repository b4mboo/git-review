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

      # FIXME: Move out of GH class.
      # show latest pull request number
      def latest_request_number(repo = source_repo)
        requests(repo).collect(&:number).sort.last.to_i
      end

      # FIXME: Move out of GH class.
      # get the number of the request that matches the title
      def request_number_by_title(title, repo = source_repo)
        request = requests(repo).find { |r| r.title == title }
        request.number if request
      end

      # FIXME: Remove this method after merging create_pull_request from commands.rb, currently no specs
      def request_url_for(target_repo, request_number)
        "https://github.com/#{target_repo}/pull/#{request_number}"
      end
      # FIXME: Needs to be moved into Server class, as its result is dependent of
      # the actual provider (i.e. GitHub or BitBucket).
      def remote_url_for(user_name, repo_name = repo_info_from_config.last)
        "git@github.com:#{user_name}/#{repo_name}.git"
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

      private

      def configure_oauth
        begin
          print_auth_message
          prepare_username unless github_login
          prepare_password
          prepare_description
          authorize
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
        puts "Requesting a OAuth token for git-review."
        puts "This procedure will grant access to your public and private "\
        "repositories."
        puts "You can revoke this authorization by visiting the following page: "\
        "https://github.com/settings/applications"
      end

      def prepare_username
        print "Please enter your GitHub's username: "
        @username = STDIN.gets.chomp
      end

      def prepare_password
        print "Please enter your GitHub's password for #{@username} "\
        "(it won't be stored anywhere): "
        @password = STDIN.noecho(&:gets).chomp
      end

      def prepare_otp
        print "PLease enter your One-Time-Password for GitHub's 2 Factor Authorization:"
        @otp = STDIN.gets.chomp
      end

      def prepare_description(chosen_description=nil)
        if chosen_description
          @description = chosen_description
        else
          @description = "git-review - #{Socket.gethostname}"
          puts "Please enter a description to associate to this token, it will "\
          "make easier to find it inside of GitHub's application page."
          puts "Press enter to accept the proposed description"
          print "Description [#{@description}]:"
          user_description = STDIN.gets.chomp
          @description = user_description.empty? ? @description : user_description
        end
      end

      def authorize
        client = Octokit::Client.new :login => @username, :password => @password
        begin
          auth = client.create_authorization(:scopes => %w(repo),
                                             :note => @description)
        rescue Octokit::OneTimePasswordRequired
          prepare_otp
          auth = client.create_authorization(:scopes => %w(repo),
                                             :note => @description,
                                             :headers => {'X-GitHub-OTP' => @otp})
        end
        save_oauth_token(auth)
      end

      def save_oauth_token(auth)
        settings.oauth_token = auth.token
        settings.username = @username
        settings.save!
        puts "OAuth token successfully created.\n"
      end

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

    end

  end

end
