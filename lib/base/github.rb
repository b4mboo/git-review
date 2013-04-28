require 'net/http'
require 'net/https'
# Used to handle json data
require 'yajl'
# Required to hide password
require 'io/console'
# Required by yajl for decoding
require 'stringio'
# Used to retrieve hostname
require 'socket'
require 'singleton'

# module GitReview

  class Github

    include Singleton

    attr_reader :github

    def initialize()
      configure_github_access
    end

    def configure_github_access
      if Settings.instance.oauth_token
        @github = Octokit::Client.new(
          :login          => Settings.instance.username,
          :oauth_token    => Settings.instance.oauth_token,
          :auto_traversal => true
        )
        @github.login
      else
        configure_oauth
        configure_github_access
      end
    end

    def pull_requests(repo, state='open')
      requests = @github.pull_requests(repo, state).collect { |request|
        Request.new.update_from_mash(request)
      }
    end

    def pull_request(repo, number)
      Request.new.update_from_mash(@github.pull_request(repo, number))
    end

  private

    def configure_oauth(chosen_description = nil)
      begin
        prepare_username_and_password
        prepare_descirption
        authorize
      rescue Errors::AuthenticationError => e
        warn e.message
        retry
      rescue Errors::FatalError => e
        warn e.message
        exit 1
      end
    end

    def prepare_username_and_password(chosen_description = nil)
      puts "Requesting a OAuth token for git-review."
      puts "This procedure will grant access to your public and private repositories."
      puts "You can revoke this authorization by visiting the following page: " +
        "https://github.com/settings/applications"
      print "Plese enter your GitHub's username: "
      @username = STDIN.gets.chomp
      print "Plese enter your GitHub's password (it won't be stored anywhere): "
      @password = STDIN.noecho(&:gets).chomp
      print "\n"
    end

    def prepare_descirption(chosen_description=nil)
      if chosen_description
        @description = chosen_description
      else
        @description = "git-review - #{Socket.gethostname}"
        puts "Please enter a descriptiont to associate to this token, it will " +
          "make easier to find it inside of github's application page."
        puts "Press enter to accept the proposed description"
        print "Description [#{@description}]:"
        user_description = STDIN.gets.chomp
        @description = user_description.empty? ? @description : user_description
      end
    end

    def authorize
      uri = URI("https://api.github.com/authorizations")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      req.basic_auth(@username, @password)
      req.body = Yajl::Encoder.encode(
        {
          "scopes" => ["repo"],
          "note"   => @description
        }
      )
      response = http.request(req)
      if response.code == '201'
        parser_response      = Yajl::Parser.parse(response.body)
        settings             = Settings.instance
        settings.oauth_token = parser_response['token']
        settings.username    = @username
        settings.save!
        puts "OAuth token successfully created.\n"
      elsif response.code == '401'
        raise Errors::AuthenticationError
      else
        raise Errors::FatalError(response.body)
      end
    end

  end

# end
