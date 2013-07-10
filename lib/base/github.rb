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
require 'grit'
require 'singleton'

require_relative 'local'

module GitReview

  class Github

    include Singleton
    include Internals

    attr_reader :github
    attr_accessor :local_repo, :current_requests

    def initialize
      #configure_github_access
    end

    # setup connection with Github via OAuth
    # @return [String] the username logged in
    def configure_github_access
      settings = ::GitReview::Settings.instance
      if settings.oauth_token && settings.username
        @github = Octokit::Client.new(
          :login          => settings.username,
          :oauth_token    => settings.oauth_token,
          :auto_traversal => true
        )
        @github.login
      else
        configure_oauth
        configure_github_access
      end
    end

    # @return [Repository, nil] the local repo in the current directory
    def initialize_local_repo
      unless source_repo.nil?
        @local_repo = ::GitReview::Repository.new
        @local_repo.full_name = source_repo
      end
    end

    # list pull requests for a repository
    def pull_requests(repo, state='open')
      args = stringify(repo, state)
      @github.pull_requests(*args).collect { |request|
        ::GitReview::Request.new.update_from_mash(request)
      }
    end

    # get a pull request
    def pull_request(repo, number)
      args = stringify(repo, number)
      ::GitReview::Request.new.update_from_mash(@github.pull_request(*args))
    end

    # get all comments attached to an issue
    def issue_comments(repo, number)
      args = stringify(repo, number)
      @github.issue_comments(*args).collect { |comment|
        ::GitReview::Comment.new.update_from_mash(comment)
      }
    end

    # get a single comment attached to an issue
    def issue_comment(repo, number)
      args = stringify(repo, number)
      ::GitReview::Comment.new.update_from_mash(@github.issue_comment(*args))
    end

    # list comments on a pull request
    def pull_request_comments(repo, number)
      args = stringify(repo, number)
      @github.pull_request_comments(*args) { |comment|
        ::GitReview::Comment.new.update_from_mash(comment)
      }
    end
    alias_method :pull_comments, :pull_request_comments
    alias_method :review_comments, :pull_request_comments

    # list commits on a pull request
    def pull_request_commits(repo, number)
      args = stringify(repo, number)
      @github.pull_request_commits(*args) { |commit|
        ::GitReview::Commit.new.update_from_mash(commit)
      }
    end
    alias_method :pull_commits, :pull_request_commits

    # close an issue
    def close_issue(repo, number)
      args = stringify(repo, number)
      @github.close_issue(*args)
    end

    # add a comment to an issue
    def add_comment(repo, number, comment)
      args = stringify(repo, number, comment)
      @github.add_comment(*args)
    end

    # create a pull request
    def create_pull_request(repo, base, head, title, body)
      args = stringify(repo, base, head, title, body)
      @github.create_pull_request(*args)
    end

    # get latest changes from Github.
    def update(state='open')
      @current_requests = pull_requests(@local_repo, state)
      repos = @current_requests.collect { |request|
        repo = request.head.repo
        "#{repo.owner}/#{repo.name}" if repo
      }
      repos.uniq.compact.each do |rep|
        git_call "fetch git@github.com:#{rep}.git +refs/heads/*:refs/pr/#{rep}/*"
      end
    end

    # @return [Boolean] the existence of specified request
    def request_exists?(state='open', request_id=nil)
      # NOTE: If request_id is set explicitly we might need to update to get the
      # latest changes from GitHub, as this is called from within another method.
      #automated = !request_id.nil?
      #update(state) if automated
      update(state)
      request_id = request_id.to_i
      if request_id == 0
        raise ::GitReview::Errors::InvalidRequestIDError
      end
      @current_requests.any? { |r| r.number == request_id }
      #unless @current_request
      #  # additional try to get an older request from Github by specifying the id.
      #  request = pull_request(source_repo, request_id)
      #  @current_request = request if request.state == state
      #end
      #if @current_request
      #  true
      #else
      #  # No output for automated checks.
      #  unless automated
      #    puts "Could not find an '#{state}' request wit ID ##{request_id}."
      #  end
      #  false
      #end
    end

    # @return [Request] the request if exists
    def get_request(state='open', request_id)
      if request_exists?(state, request_id)
        @current_requests.find { |req| req.number == request_id.to_i }
      end
    end

    # @return [Array(String, String)] user and repo name from local git config
    def repo_info_from_config
      git_config = ::GitReview::Local.instance.config
      url = git_config['remote.origin.url']
      raise ::GitReview::Errors::InvalidGitRepositoryError if url.nil?

      user, project = github_url_matching(url)
      # If there are no results yet, look for 'insteadof' substitutions
      # in URL and try again.
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
      user, repo = repo_info_from_config
      if user && repo
        "#{user}/#{repo}"
      end
    end

    # @return [String] the current source branch
    def source_branch
      git_call('branch').chomp.match(/\*(.*)/)[0][2..-1]
    end

    # @return [String] combine source repo and branch
    def source
      "#{source_repo}/#{source_branch}"
    end

  private

    def configure_oauth
      begin
        prepare_username_and_password
        prepare_description
        authorize
      rescue ::GitReview::Errors::AuthenticationError => e
        warn e.message
      rescue ::GitReview::Errors::UnprocessableState => e
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
        raise ::GitReview::Errors::AuthenticationError
      else
        raise ::GitReview::Errors::UnprocessableState, response.body
      end
    end

    def save_oauth_token(token)
      settings = ::GitReview::Settings.instance
      settings.oauth_token = token
      settings.username = @username
      settings.save!
      puts "OAuth token successfully created.\n"
    end

    # stringify all arguments depending on how to_s is defined for each
    def stringify(*args)
      args.map(&:to_s)
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
