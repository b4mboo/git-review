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


module GitReview

  class Github

    include Internals

    attr_reader :github
    attr_accessor :source_repo

    # acts like a singleton class but it's actually not
    # use ::GitReview::Github.instance everywhere except in tests
    def self.instance
      @instance ||= new
    end

    def initialize
      configure_github_access
    end

    # setup connection with Github via OAuth
    # @return [String] the username logged in
    def configure_github_access
      settings = ::GitReview::Settings.instance
      if settings.oauth_token && settings.username
        @github = Octokit::Client.new(
          :login          => settings.username,
          :access_token    => settings.oauth_token,
          :auto_traversal => true
        )
        @github.login
      else
        configure_oauth
        configure_github_access
      end
    end

    # @return [Boolean, Hash] the specified request if exists, otherwise false.
    #   Instead of true, the request itself is returned, so another round-trip
    #   of pull_request can be avoided.
    def request_exists?(number, state='open')
      return false if number.nil?
      request = @github.pull_request(source_repo, number)
      request.state == state ? request : false
    rescue Octokit::NotFound
      false
    end

    # an alias to pull_requests
    def current_requests
      @github.pull_requests(source_repo)
    end

    # a more detailed collection of requests
    def current_requests_full
      @github.pull_requests(source_repo).collect { |request|
        @github.pull_request(source_repo, request.number)
      }
    end

    def update
      git_call('fetch origin')
    end

    # @return [Array(String, String)] user and repo name from local git config
    def repo_info_from_config
      git_config = ::GitReview::Local.instance.config
      url = git_config['remote.origin.url']
      raise ::GitReview::InvalidGitRepositoryError if url.nil?

      user, project = github_url_matching(url)
      # if there are no results yet, look for 'insteadof' substitutions
      #   in URL and try again
      unless user && project
        insteadof_url, true_url = github_insteadof_matching(git_config, url)
        if insteadof_url and true_url
          url = url.sub(insteadof_url, true_url)
          user, project = github_url_matching(url)
        end
      end
      [user, project]
    end

    # @return [String] the source repo
    def source_repo
      # cache source_repo
      if @source_repo
        @source_repo
      else
        user, repo = repo_info_from_config
        @source_repo = "#{user}/#{repo}" if user && repo
      end
    end

    def commit_discussion(number)
      pull_commits = @github.pull_commits(source_repo, number)
      repo = @github.pull_request(source_repo, number).head.repo.full_name
      discussion = ["Commits on pull request:\n\n"]
      discussion += pull_commits.collect { |commit|
        # commit message
        name = commit.committer.login
        output = "\e[35m#{name}\e[m "
        output << "committed \e[36m#{commit.sha[0..6]}\e[m "
        output << "on #{format_time(commit.commit.committer.date)}"
        output << ":\n#{''.rjust(output.length + 1, "-")}\n"
        output << "#{commit.commit.message}"
        output << "\n\n"
        result = [output]

        # comments on commit
        comments = @github.commit_comments(repo, commit.sha)
        result + comments.collect { |comment|
          name = comment.user.login
          output = "\e[35m#{name}\e[m "
          output << "added a comment to \e[36m#{commit.sha[0..6]}\e[m"
          output << " on #{format_time(comment.created_at)}"
          unless comment.created_at == comment.updated_at
            output << " (updated on #{format_time(comment.updated_at)})"
          end
          output << ":\n#{''.rjust(output.length + 1, "-")}\n"
          output << comment.body
          output << "\n\n"
        }
      }
      discussion.compact.flatten unless discussion.empty?
    end

    def issue_discussion(number)
      comments = @github.issue_comments(source_repo, number)
      discussion = ["\nComments on pull request:\n\n"]
      discussion += comments.collect { |comment|
        name = comment.user.login
        output = "\e[35m#{name}\e[m "
        output << "added a comment to \e[36m#{comment.id}\e[m"
        output << " on #{format_time(comment.created_at)}"
        unless comment.created_at == comment.updated_at
          output << " (updated on #{format_time(comment.updated_at)})"
        end
        output << ":\n#{''.rjust(output.length + 1, "-")}\n"
        output << comment.body
        output << "\n\n"
      }
      discussion.compact.flatten unless discussion.empty?
    end

    # show discussion for a request
    def discussion(number)
      commit_discussion(number) +
      issue_discussion(number)
    end

    # delegate methods that interact with Github to Octokit client
    def method_missing(method, *args)
      if @github.respond_to?(method)
        @github.send(method, *args)
      else
        super
      end
    end

    def respond_to?(method)
      @github.respond_to?(method) || super
    end

  private

    def configure_oauth
      begin
        prepare_username_and_password
        prepare_description
        authorize
      rescue ::GitReview::AuthenticationError => e
        warn e.message
      rescue ::GitReview::UnprocessableState => e
        warn e.message
        exit 1
      end
    end

    def prepare_username_and_password
      puts "Requesting a OAuth token for git-review."
      puts "This procedure will grant access to your public and private "\
      "repositories."
      puts "You can revoke this authorization by visiting the following page: "\
      "https://github.com/settings/applications"
      print "Please enter your GitHub's username: "
      @username = STDIN.gets.chomp
      print "Please enter your GitHub's password (it won't be stored anywhere): "
      @password = STDIN.noecho(&:gets).chomp
      print "\n"
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
      uri = URI('https://api.github.com/authorizations')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      req.basic_auth(@username, @password)
      req.body = Yajl::Encoder.encode(
        {
          :scopes => %w(repo),
          :note   => @description
        }
      )
      response = http.request(req)
      if response.code == '201'
        parser_response = Yajl::Parser.parse(response.body)
        save_oauth_token(parser_response['token'])
      elsif response.code == '401'
        raise ::GitReview::AuthenticationError
      else
        raise ::GitReview::UnprocessableState, response.body
      end
    end

    def save_oauth_token(token)
      settings = ::GitReview::Settings.instance
      settings.oauth_token = token
      settings.username = @username
      settings.save!
      puts "OAuth token successfully created.\n"
    end

    # extract user and project name from GitHub URL.
    def github_url_matching(url)
      matches = /github\.com.(.*?)\/(.*)/.match(url)
      matches ? [matches[1], matches[2].sub(/\.git\z/, '')] : [nil, nil]
    end

    # look for 'insteadof' substitutions in URL.
    def github_insteadof_matching(config, url)
      first_match = config.keys.collect { |key|
        [config[key], /url\.(.*github\.com.*)\.insteadof/.match(key)]
      }.find { |insteadof_url, true_url|
        url.index(insteadof_url) and true_url != nil
      }
      first_match ? [first_match[0], first_match[1][1]] : [nil, nil]
    end

  end

end
