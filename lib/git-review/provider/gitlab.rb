require 'gitlab'
require 'uri'

module GitReview

  module Provider

    class Gitlab < Base

      include ::GitReview::Helpers

      # @return [String] Authenticated username
      def configure_access
        if settings[token_key]
          @client = ::Gitlab.client(
            :endpoint => "https://#{gitlab_host}/api/v3",
            :private_token => settings[token_key]
          )
        else
          configure_token
          configure_access
        end
      end

      # @return [Boolean, Hash] the specified request if exists, otherwise false.
      #   Instead of true, the request itself is returned, so another round-trip
      #   of merge_request can be avoided.
      def request_exists?(number, state='open')
        return false if number.nil?
        request = build_request(client.merge_request(project_id(source_repo), number))
        request.state == state ? request : false
      rescue ::Gitlab::Error::NotFound
        false
      end

      def request_exists_for_branch?(upstream = false, branch = local.source_branch)
        target_repo = local.target_repo(upstream)
        client.merge_requests(project_id(target_repo)).any? { |r| r.source_branch == branch }
      end

      # an alias to pull_requests
      def current_requests(repo=source_repo)
        client.merge_requests(project_id(repo)).map do |request|
          build_request(request,repo)
        end.reject do |request|
          # Remove invalid and closed/merged merge requests
          request.head.sha.nil? || request.state != 'open'
        end
      end

      # a more detailed collection of requests
      def current_requests_full(repo=source_repo)
        current_requests(repo)
      end

      def send_pull_request(to_upstream = false)
        target_repo = local.target_repo(to_upstream)
        base = local.target_branch
        title, body = local.create_title_and_body(base)

        # gather information before creating pull request
        latest_number = latest_request_number(target_repo)

        # create the actual pull request
        raw_request = client.create_merge_request(
          project_id(source_repo),
          title,
          :target_project_id => project_id(target_repo),
          :source_branch => local.source_branch,
          :target_branch => base
        )
        request = build_request(raw_request,target_repo)
        # switch back to target_branch and check for success
        git_call "checkout #{base}"

        # make sure the new pull request is indeed created
        new_number = request.number
        if new_number && new_number > latest_number
          puts "Successfully created new request ##{new_number}"
          puts request_url_for target_repo, raw_request.iid
        else
          puts "Pull request was not created for #{target_repo}."
        end
      end

      def close_issue(repo, request_number)
        client.update_merge_request(
          project_id(repo),
          request_number,
          :state => 'merged'
        )
      end

      def add_comment(repo, request_number, comment)
        #TODO
        puts 'TODO: Can\'t post comments yet with API'
        {:body => comment}
      end

      def repository(repo)
        build_repository(client.project(project_id(repo)))
      end

      def pull_request(repo, request_number)
        build_request(client.merge_request(project_id(repo), request_number))
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
        #TODO
        return 'N/A'
        issue_c = request.comments + request.review_comments
        commits_c = client.pull_commits(source_repo, request.number).
            inject(0) { |sum, c| sum + c.commit.comment_count }
        issue_c + commits_c
      end

      # show discussion for a request
      def discussion(number)
        #TODO
        return ['Comments not available yet from API']
        commit_discussion(number) +
        issue_discussion(number)
      end

      # show latest pull request number
      def latest_request_number(repo=source_repo)
        current_requests(repo).collect(&:number).sort.last.to_i
      end

      # FIXME: Remove this method after merging create_pull_request from commands.rb, currently no specs
      def request_url_for(target_repo, request_number)
        "https://#{gitlab_host}/#{target_repo}/merge_requests/#{request_number}"
      end

      # FIXME: Needs to be moved into Server class, as its result is dependent of
      # the actual provider (i.e. GitHub or BitBucket).
      def remote_url_for(user_name, repo_name = repo_info_from_config.last)
        "git@#{gitlab_host}:#{user_name}/#{repo_name}.git"
      end

      private

      def gitlab_host
        url = local.config['remote.origin.url']
        url = case url
              when /^http/
                url
              when /.*@.*:.*/
                "ssh://#{url.gsub(':','/')}"
              else
                raise "Unable to parse gitlab host from #{url}"
              end
        URI.parse(url).host
      end

      def token_key
        "gitlab_#{gitlab_host}_token"
      end

      def configure_token
        puts "Requesting a Gitlab private token for git-review."
        puts "This procedure will grant access to your public and private "\
        "repositories."
        puts "You can get and revoke this token by visiting the following page: "\
        "https://#{gitlab_host}/profile/account"
        print "Please enter your Gitlab's private token: "
        settings[token_key] =  STDIN.gets.chomp
        print "\n"
        settings.save!
        puts "Private token successfully saved.\n"
      end

      # extract user and project name from Gitlab URL.
      def url_matching(url)
        matches = /#{gitlab_host}.(.*?)\/(.*)/.match(url)
        matches ? [matches[1], matches[2].sub(/\.git\z/, '')] : [nil, nil]
      end

      def project_id(full_name)
        settings_key = "gitlab_project_#{gitlab_host}_#{full_name.gsub('/','_')}"
        return settings[settings_key] if settings[settings_key]
        page = 1
        until (projects = client.projects(:per_page => 100, :page => page)).empty?
          page += 1
          project = projects.select do |project|
            project.path_with_namespace == full_name
          end.first
          if project
            settings[settings_key] = project.id
            settings.save!
            break
          end
        end
        project.id
      end

      def build_repository(project)
        if project.forked_from_project
          ForkedRepository.new(
            :parent => { :full_name => project.forked_from_project.path_with_namespace } ,
            :full_name => project.path_with_namespace
          )
        else
          Repository.new(
            :full_name => project.path_with_namespace
          )
        end
      end

      def build_request(request, repo=source_repo)
        begin
          branch_info = client.branch(request.source_project_id, request.source_branch)
          project_info = client.project(request.source_project_id)
          commit_info = {
            :sha => branch_info.commit.id,
            :ref => branch_info.name,
            :label => branch_info.name,
            :user => { :login => project_info.namespace.path },
            :repo => { :full_name => project_info.path_with_namespace }
          }
        rescue ::Gitlab::Error::NotFound
          # messed up merge requests
          commit_info ||= {}

        end
        Request.new(
          :number => request.id,
          :title => request.title,
          :body => '',
          :head => commit_info,
          :state => build_state(request.state),
          :updated_at => Time.new(request.author.created_at),
          :html_url => request_url_for(source_repo, request.iid)
        )
      end

      def build_state(state)
        case state
        when 'opened'
          'open'
        when 'merged', 'closed'
          'closed'
        else
          state
        end
      end

    end

  end

end