module GitReview

  module Commands

    include ::GitReview::Helpers
    extend self

    # List all pending requests.
    def list(reverse = false)
      requests = server.current_requests_full.reject do |request|
        # Find only pending (= unmerged) requests and output summary.
        # Explicitly look for local changes git does not yet know about.
        # TODO: Isn't this a bit confusing? Maybe display pending pushes?
        local.merged? request.head.sha
      end
      source = local.source
      if requests.empty?
        puts "No pending requests for '#{source}'."
      else
        puts "Pending requests for '#{source}':"
        puts "ID      Updated    Comments  Title".pink
        print_requests(requests, reverse)
      end
    end

    # Show details for a single request.
    def show(number, full = false)
      request = server.get_request_by_number(number)
      # Determine whether to show full diff or stats only.
      option = full ? '' : '--stat '
      diff = "diff --color=always #{option}HEAD...#{request.head.sha}"
      # TODO: Refactor into using Request model.
      print_request_details request
      puts git_call(diff)
      print_request_discussions request
    end

    # Open a browser window and review a specified request.
    def browse(number)
      request = server.get_request_by_number(number)
      # FIXME: Use request.html_url as soon as we are using our Request model.
      Launchy.open request._links.html.href
    end

    # Checkout a specified request's changes to your local repository.
    def checkout(number, branch = true)
      request = server.get_request_by_number(number)
      puts 'Checking out changes to your local repository.'
      puts 'To get back to your original state, just run:'
      puts
      puts '  git checkout master'.pink
      puts
      # Ensure we are looking at the right remote.
      remote = local.remote_for_request(request)
      git_call "fetch #{remote}"
      # Checkout the right branch.
      branch_name = request.head.ref
      if branch
        if local.branch_exists?(:local, branch_name)
          if local.source_branch == branch_name
            puts "On branch #{branch_name}."
          else
            git_call "checkout #{branch_name}"
          end
        else
          git_call "checkout --track -b #{branch_name} #{remote}/#{branch_name}"
        end
      else
        git_call "checkout #{remote}/#{branch_name}"
      end
    end

    # Add an approving comment to the request.
    def approve(number)
      request = server.get_request_by_number(number)
      repo = server.source_repo
      # TODO: Make this configurable.
      comment = 'Reviewed and approved.'
      response = server.add_comment(repo, request.number, comment)
      if response[:body] == comment
        puts 'Successfully approved request.'
      else
        puts response[:message]
      end
    end

    # Accept a specified request by merging it into master.
    def merge(number)
      request = server.get_request_by_number(number)
      if request.head.repo
        message = "Accept request ##{request.number} " +
            "and merge changes into \"#{local.target}\""
        command = "merge -m '#{message}' #{request.head.sha}"
        puts
        puts "Request title:"
        puts "  #{request.title}"
        puts
        puts "Merge command:"
        puts "  git #{command}"
        puts
        puts git_call(command)
      else
        print_repo_deleted request
      end
    end

    # Close a specified request.
    def close(number)
      request = server.get_request_by_number(number)
      repo = server.source_repo
      server.close_issue(repo, request.number)
      unless server.request_exists?('open', request.number)
        puts 'Successfully closed request.'
      end
    end

    # Prepare local repository to create a new request.
    # NOTE:
    #   People should work on local branches, but especially for single commit
    #   changes, more often than not, they don't. Therefore this is called
    #   automatically before creating a pull request, such that we create a
    #   proper feature branch for them, to be able to use code review the way it
    #   is intended.
    def prepare(force_new_branch = false, feature_name = nil)
      current_branch = local.source_branch
      if force_new_branch || !local.on_feature_branch?
        feature_name ||= get_branch_name
        feature_branch = move_local_changes(
          current_branch, local.sanitize_branch_name(feature_name)
        )
      else
        feature_branch = current_branch
      end
      [current_branch, feature_branch]
    end

    # Create a new request.
    def create(upstream = false)
      # Prepare original_branch and local_branch.
      # TODO: Allow to use the same switches and parameters that prepare takes.
      original_branch, local_branch = prepare
      # Don't create request with uncommitted changes in current branch.
      if local.uncommitted_changes?
        puts 'You have uncommitted changes.'
        puts 'Please stash or commit before creating the request.'
        return
      end
      if local.new_commits?(upstream)
        # Feature branch differs from local or upstream master.
        if server.request_exists_for_branch?(upstream)
          puts 'A pull request already exists for this branch.'
          puts 'Please update the request directly using `git push`.'
          return
        end
        # Push latest commits to the remote branch (create if necessary).
        remote = local.remote_for_branch(local_branch) || 'origin'
        git_call(
          "push --set-upstream #{remote} #{local_branch}", debug_mode, true
        )
        server.send_pull_request upstream
        # Return to the user's original branch.
        git_call "checkout #{original_branch}"
      else
        puts 'Nothing to push to remote yet. Commit something first.'
      end
    end

    # Remove remotes with 'review' prefix (left over from previous reviews).
    # Prune all existing remotes and delete obsolete branches (left over from
    # already closed requests).
    def clean(number = nil, force = false, all = false)
      git_call "checkout #{local.target_branch}"
      local.prune_remotes
      # Determine strategy to clean.
      if all
        local.clean_all
      else
        local.clean_single(number, force)
      end
      # Remove al review remotes without existing local branches.
      local.clean_remotes
    end

    # Start a console session (used for debugging)
    def console(number = nil)
      puts 'Entering debug console.'
      request = server.get_request_by_number(number) if number

      if RUBY_VERSION.to_f >= 2
        begin
          require 'byebug'
          byebug
        rescue LoadError => e
          puts
          puts 'Missing debugger, please install byebug:'
          puts '  gem install byebug'
          puts
        end
      else
        begin
          require 'ruby-debug'
          Debugger.start
          debugger
        rescue LoadError => e
          puts
          puts 'Missing debugger, please install ruby-debug:'
          puts '  gem install ruby-debug'
          puts
        end
      end
      puts 'Leaving debug console.'
    end


    private

    def request_summary(request)
      line = request.number.to_s.review_ljust(8)
      line << request.updated_at.review_time.review_ljust(11)
      line << server.comments_count(request).to_s.review_ljust(10)
      line << request.title.review_ljust(91)
      line
    end

    def print_requests(requests, reverse=false)
      # put all output lines in a hash first, keyed by request number
      # this is to make sure the order is still correct even if we use
      #   multi-threading to retrieve the requests
      output = {}
      requests.each { |req| output[req.number] = request_summary(req) }
      numbers = output.keys.sort
      numbers.reverse! if reverse
      numbers.each { |n| puts output[n] }
    end

    def print_request_details(request)
      comments_count = server.comments_count(request)
      puts 'ID        : ' + request.number.to_s
      puts 'Label     : ' + request.head.label
      puts 'Updated   : ' + request.updated_at.review_time
      puts 'Comments  : ' + comments_count.to_s
      puts
      puts request.title
      puts
      unless request.body.empty?
        puts request.body
        puts
      end
    end

    def print_request_discussions(request)
      puts 'Progress  :'
      puts
      puts server.discussion(request.number)
    end

    # someone deleted the source repo
    def print_repo_deleted(request)
      user = request.head.user.login
      url = request.patch_url
      puts "Sorry, #{user} deleted the source repository."
      puts "git-review doesn't support this."
      puts "Tell the contributor not to do this."
      puts
      puts "You can still manually patch your repo by running:"
      puts
      puts "  curl #{url} | git am"
      puts
    end

    # ask for branch name if not provided
    # @return [String] sanitized branch name
    def get_branch_name
      puts 'Please provide a name for the branch:'
      local.sanitize_branch_name gets.chomp
    end

    # @return [String] the complete feature branch name
    def create_feature_name(new_branch)
      "review_#{Time.now.strftime("%y%m%d")}_#{new_branch}"
    end

    # Move uncommitted changes from original_branch to a feature_branch.
    # @return [String] the new local branch uncommitted changes are moved to
    def move_local_changes(original_branch, feature_name)
      feature_branch = create_feature_name(feature_name)
      # By checking out the feature branch, the commits on the original branch
      # are copied over. That way we only need to remove pending (local) commits
      # from the original branch.
      git_call "checkout -b #{feature_branch}"
      if local.source_branch == feature_branch
        # Save any uncommitted changes, to be able to reapply them later.
        save_uncommitted_changes = local.uncommitted_changes?
        git_call('stash') if save_uncommitted_changes
        # Go back to original branch and get rid of pending (local) commits.
        git_call("checkout #{original_branch}")
        remote = local.remote_for_branch(original_branch)
        remote += '/' if remote
        git_call("reset --hard #{remote}#{original_branch}")
        git_call("checkout #{feature_branch}")
        git_call('stash pop') if save_uncommitted_changes
        feature_branch
      end
    end

    def server
      @server ||= ::GitReview::Server.instance
    end

    def local
      @local ||= ::GitReview::Local.instance
    end

  end

end
