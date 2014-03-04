require 'net/http'
require 'net/https'
require 'yajl'
require 'io/console'
require 'stringio'
require 'socket'

module GitReview

  module Provider

    class Github < Base

      include ::GitReview::Helpers

      # Find a request by a specified number and return it (or nil otherwise).
      def request(number)
        raise ::GitReview::InvalidRequestIDError unless number
        attributes = client.pull_request(source_repo, number)
        Request.from_github(server, attributes)
      rescue Octokit::NotFound
        raise ::GitReview::InvalidRequestIDError
      end

      # Determine whether a request for a specified number and state exists.
      def request_exists?(number, state = 'open')
        request = request(number)
        request && request.state == state
      end

      def request_exists_for_branch?(upstream = false, branch = local.source_branch)
        target_repo = local.target_repo(upstream)
        client.pull_requests(target_repo).any? { |r| r.head.ref == branch }
      end

      # an alias to pull_requests
      def current_requests(repo = source_repo)
        client.pull_requests repo
      end

      # a more detailed collection of requests
      def current_requests_full(repo = source_repo)
        threads = []
        requests = []
        client.pull_requests(repo).each do |req|
          threads << Thread.new {
            requests << client.pull_request(repo, req.number)
          }
        end
        threads.each(&:join)
        requests
      end

      def send_pull_request(to_upstream = false)
        target_repo = local.target_repo(to_upstream)
        head = local.head
        base = local.target_branch
        title, body = local.create_title_and_body(base)

        # gather information before creating pull request
        latest_number = latest_request_number(target_repo)

        # create the actual pull request
        create_pull_request(target_repo, base, head, title, body)
        # switch back to target_branch and check for success
        git_call "checkout #{base}"

        # make sure the new pull request is indeed created
        new_number = request_number_by_title(title, target_repo)
        if new_number && new_number > latest_number
          puts "Successfully created new request ##{new_number}"
          puts request_url_for target_repo, new_number
        else
          puts "Pull request was not created for #{target_repo}."
        end
      end

      def commit_discussion(number)
        pull_commits = client.pull_commits(source_repo, number)
        repo = client.pull_request(source_repo, number).head.repo.full_name
        discussion = ["Commits on pull request:\n\n"]
        discussion += pull_commits.collect { |commit|
          # commit message
          name = commit.committer.login
          output = "\e[35m#{name}\e[m "
          output << "committed \e[36m#{commit.sha[0..6]}\e[m "
          output << "on #{commit.commit.committer.date.review_time}"
          output << ":\n#{''.rjust(output.length + 1, "-")}\n"
          output << "#{commit.commit.message}"
          output << "\n\n"
          result = [output]

          # comments on commit
          comments = client.commit_comments(repo, commit.sha)
          result + comments.collect { |comment|
            name = comment.user.login
            output = "\e[35m#{name}\e[m "
            output << "added a comment to \e[36m#{commit.sha[0..6]}\e[m"
            output << " on #{comment.created_at.review_time}"
            unless comment.created_at == comment.updated_at
              output << " (updated on #{comment.updated_at.review_time})"
            end
            output << ":\n#{''.rjust(output.length + 1, "-")}\n"
            output << comment.body
            output << "\n\n"
          }
        }
        discussion.compact.flatten unless discussion.empty?
      end

      def issue_discussion(number)
        comments = client.issue_comments(source_repo, number) +
            client.review_comments(source_repo, number)
        discussion = ["\nComments on pull request:\n\n"]
        discussion += comments.collect { |comment|
          name = comment.user.login
          output = "\e[35m#{name}\e[m "
          output << "added a comment to \e[36m#{comment.id}\e[m"
          output << " on #{comment.created_at.review_time}"
          unless comment.created_at == comment.updated_at
            output << " (updated on #{comment.updated_at.review_time})"
          end
          output << ":\n#{''.rjust(output.length + 1, "-")}\n"
          output << comment.body
          output << "\n\n"
        }
        discussion.compact.flatten unless discussion.empty?
      end

      # get the number of comments, including comments on commits
      def comments_count(request)
        issue_c = request.comments + request.review_comments
        commits_c = client.pull_commits(source_repo, request.number).
            inject(0) { |sum, c| sum + c.commit.comment_count }
        issue_c + commits_c
      end

      # show discussion for a request
      def discussion(number)
        commit_discussion(number) +
        issue_discussion(number)
      end

      # show latest pull request number
      def latest_request_number(repo = source_repo)
        current_requests(repo).collect(&:number).sort.last.to_i
      end

      # get the number of the request that matches the title
      def request_number_by_title(title, repo = source_repo)
        request = current_requests(repo).find { |r| r.title == title }
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


# GitHub specific constructor for git-review's request model.
class Request

  # Create a new request instance from a GitHub-structured attributes hash.
  def self.from_github(server, response)
    self.new(
      server: server,
      number: response.number,
      title: response.title,
      body: response.body,
      state: response.state,
      html_url: response._links.html.href,
      # FIXME: Where do we get the patch URL from?
      patch_url: nil,
      updated_at: response.updated_at,
      comments: response.comments,
      review_comments: response.review_comments,
      head: {
        sha: response.head.sha,
        ref: response.head.ref,
        label: response.head.label,
        user: {
          login: response.head.user.login
        },
        repo: {
          # NOTE: This can become nil, if the repo has been deleted ever since.
          owner: (response.head.repo ? response.head.repo.owner : nil),
          name: (response.head.repo ? response.head.repo.name : nil)
        }
      }
    )
  end

end
