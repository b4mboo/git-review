require 'faraday_middleware'
require 'oauth'
require 'bucketkit'

module GitReview

  module Provider

    class Bitbucket < Base

      def request(number, repo = source_repo)
        raise ::GitReview::InvalidRequestIDError unless number
        Request.from_bitbucket(server, client.pull_request(repo, number))
      rescue Bucketkit::NotFound
        raise ::GitReview::InvalidRequestIDError
      end

      def requests(repo = source_repo)
        Request.from_bitbucket(server, client.pull_requests(repo).values)
      end

      def request_comments(number, repo = source_repo)
        Comment.from_bitbucket(server, client.pull_request_comments(repo, number).values)
      end

      def create_request(repo, base, head, title, body)
        # TODO: See whether we can form a Request instance from the response.
        client.create_pull_request(repo, title, head, base)
      end

      def commits(number, repo = source_repo)
        Commit.from_bitbucket(server, client.pull_request_commits(repo, number).values)
      end

      def commit_comments(sha, repo = source_repo)
        Comment.from_bitbucket(server, client.commit_comments(repo, sha).values)
      end

      def approve(number, repo = source_repo)
        response = client.approve_pull_request(repo, number)
        if response[:approved]
          'Successfully approved request.'
        else
          response[:error][:message]
        end
      end

      def close(number, repo = source_repo)
        # Closing pull request is not currently supported for BitBucket.
        # Pull request is considered 'closed' once they have been merged.
        response = client.merge_pull_request(repo, number)
        if response[:state] == 'MERGED'
          'Successfully closed request.'
        else
          'Failed to close request.'
        end
      end

      def head
        GitReview::Local.instance.source_branch
      end

      def url_for_request(repo, number)
        "https://#{name}.#{tld}/#{repo}/pull-request/#{number}"
      end

      def url_for_remote(repo)
        "git@#{name}.#{tld}:#{repo}.git"
      end

      def name
        'bitbucket'
      end

      def tld
        'org'
      end

      def login
        settings.bitbucket_username
      end

      private

      def configure_access
        configure_oauth unless authenticated?
        @client = Bucketkit::Client.new(
            login: settings.bitbucket_username,
            oauth_tokens: oauth_tokens
        )
        @client.login
      end

      def configure_oauth
        print_auth_message
        prepare_username
        prepare_password
        prepare_description
        authorize
      end

      def print_auth_message
        puts 'Requesting an OAuth token for git-review.'
        puts 'This procedure will grant access to your repositories.'
        puts 'You can revoke this authorization by visiting the following page:'
        puts 'https://bitbucket.org/account/user/USERNAME/api'
      end

      def prepare_username
        print 'Please enter your BitBucket username: '
        @username = STDIN.gets.chomp
      end

      def prepare_password
        print "Please enter your BitBucket password for #{@username} "\
        '(it won\'t be stored anywhere): '
        @password = STDIN.noecho(&:gets).chomp
      end

      def prepare_description
        @description = "git-review - #{Socket.gethostname}"
        puts 'Please enter a description to associate to this token.'
        puts 'It will make it easier to identify it on BitBucket.'
        puts 'Press enter to continue with the proposed description.'
        print "Description [#{@description}]:"
        user_input = STDIN.gets.chomp
        @description = user_input unless user_input.empty?
      end

      def authorize
        get_consumer_token
        get_access_token
        save_oauth_token
      end

      def get_consumer_token
        @connection = connection
        @connection.basic_auth @username, @password
        response = @connection.post "/1.0/users/#{@username}/consumers" do |req|
          req.body = Yajl.dump(
              {
                  :name => 'git-review',
                  :description => @description
              }
          )
        end
        @consumer_key = response.body['key']
        @consumer_secret = response.body['secret']
      end

      def get_access_token
        consumer = OAuth::Consumer.new(
            @consumer_key, @consumer_secret,
            {
                :site => 'https://bitbucket.org/!api/1.0',
                :authorize_path => '/oauth/authenticate'
            }
        )
        request_token = consumer.get_request_token
        puts "You will be directed to BitBucket's website for authorization."
        puts "You can also visit #{request_token.authorize_url}."
        Launchy.open(request_token.authorize_url)
        puts "After you've authorized the token, enter the verifier code below:"
        verifier = STDIN.gets.chomp
        access_token = request_token.get_access_token(:oauth_verifier => verifier)
        @token = access_token.token
        @token_secret = access_token.secret
      end

      def save_oauth_token
        settings = ::GitReview::Settings.instance
        settings.bitbucket_consumer_key = @consumer_key
        settings.bitbucket_consumer_secret = @consumer_secret
        settings.bitbucket_token = @token
        settings.bitbucket_token_secret = @token_secret
        settings.bitbucket_username = @username
        settings.save!
        puts "OAuth token successfully created.\n"
      end

      def connection
        connection = Faraday.new('https://api.bitbucket.org') do |c|
          c.request :oauth, oauth_tokens if authenticated?
          c.request :json
          c.response :mashify
          c.response :json
          c.adapter Faraday.default_adapter
        end
        connection.headers[:user_agent] = 'Git-Review'
        connection
      end

      def authenticated?
        settings.bitbucket_consumer_key &&
            settings.bitbucket_consumer_secret &&
            settings.bitbucket_token &&
            settings.bitbucket_token_secret
      end

      def oauth_tokens
        @oauth_tokens ||=
            if authenticated?
              {
                  :consumer_key => settings.bitbucket_consumer_key,
                  :consumer_secret => settings.bitbucket_consumer_secret,
                  :token => settings.bitbucket_token,
                  :token_secret => settings.bitbucket_token_secret
              }
            end
      end

    end

  end

end
