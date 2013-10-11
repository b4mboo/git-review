module GitReview

  module Provider

    class Github < Base

      # @return [String] Authenticated username
      def configure_access
        if settings.github_oauth_token && settings.github_username
          @client = Octokit::Client.new(
            login: settings.github_username,
            access_token: settings.github_oauth_token,
            auto_traversal: true
          )

          @client.login
        else
          configure_oauth
          configure_access
        end
      end

      # a default collection of requests
      def current_requests(repo = source_repo)
        client.pull_requests(repo)
      end

      # a detailed collection of requests
      def detailed_requests(repo = source_repo)
        threads = []
        requests = []

        client.pull_requests(repo).each do |req|
          threads << Thread.new {
            requests << client.pull_request(repo, req.number)
          }
        end

        threads.each { |t| t.join }
        requests
      end

      def send_pull_request(to_upstream = false)
        head = local.head
        base = local.target_branch

        target_repo = local.target_repo(to_upstream)
        title, body = local.create_title_and_body(base)

        begin
          # FIXME: initialize request model
          response = create_pull_request(target_repo, base, head, title, body)
        rescue => e
          puts e.message if debug_mode?
          response = nil
        end

        if response
          git_call("checkout #{base}")

          puts "Successfully created new request #{response.number}"
          puts response._links.html.href # FIXME: refactor bad link access
        else
          puts "Pull request was not created for #{target_repo}."
        end
      end










      # @return [Boolean, Hash] the specified request if exists, otherwise false.
      #   Instead of true, the request itself is returned, so another round-trip
      #   of pull_request can be avoided.
      def request_exists?(number, state='open')
        return false if number.nil?
        request = client.pull_request(source_repo, number)
        request.state == state ? request : false
      rescue Octokit::NotFound
        false
      end

      def request_exists_for_branch?(upstream=false, branch=local.source_branch)
        target_repo = local.target_repo(upstream)
        client.pull_requests(target_repo).any? { |r|
          r.head.ref == branch
        }
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










      # @return [String] SSH url for github
      def remote_url_for(user_name)
        "git@github.com:#{user_name}/#{repo_info_from_config.last}.git"
      end

      # @return [String] Current username
      def login
        settings.github_username
      end

      private

      def authorize
        uri = URI('https://api.github.com/authorizations')

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        req = Net::HTTP::Post.new(uri.request_uri)
        req.basic_auth(@username, @password)

        req.body = Yajl::Encoder.encode({
          scopes: %w(repo),
          note: @description
        })

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

      def prepare_username_and_password
        puts "Requesting a OAuth token, this procedure will grant access to your public and private repositories."
        puts "You can revoke this authorization by visiting the following page: https://github.com/settings/applications"

        print "Please enter your GitHub username: "
        @username = STDIN.gets.chomp

        print "Please enter your GitHub password: "
        @password = STDIN.noecho(&:gets).chomp

        print "\n"
      end

      def save_oauth_token(token)
        settings = ::GitReview::Settings.instance

        settings.github_oauth_token = token
        settings.github_username = @username
        settings.save!

        puts "OAuth token successfully created.\n"
      end

      def url_matching(url)
        matches = /github\.com.(.*?)\/(.*)/.match(url)
        matches ? [matches[1], matches[2].sub(/\.git\z/, '')] : [nil, nil]
      end

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
