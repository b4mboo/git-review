module GitReview

  module Commands

    include ::GitReview::Helpers
    extend self

    # List all pending requests.
    def list(reverse = false)
      requests = server.pending_requests
      source = local.source
      if requests.empty?
        puts "No pending requests for '#{source}'."
      else
        puts "Pending requests for '#{source}':"
        puts "ID      Updated    Title".pink
        requests.sort_by!(&:number)
        requests.reverse! if reverse
        requests.collect(&:summary).each(&method(:puts))
      end
    end

    # Show details for a single request.
    def show(number, full = false)
      request = server.request(number)
      # Determine whether to show full diff or stats only.
      option = full ? '' : '--stat '
      diff = "diff --color=always #{option}HEAD...#{request.head.sha}"
      puts request.details
      puts git_call(diff)
      puts request.discussion
    end

    # Open a browser window and review a specified request.
    def browse(number)
      Launchy.open server.request(number).html_url
    end

    # Checkout a specified request's changes to your local repository.
    def checkout(number, branch = true)
      request = server.request(number)
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
      request = server.request(number)
      repo = server.source_repo
      response = server.approve(request.number, repo)
      puts response
    end

    # Accept a specified request by merging it into master.
    def merge(number)
      request = server.request(number)
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
        puts request.missing_repo_warning
      end
    end

    # Close a specified request.
    def close(number)
      request = server.request(number)
      # FIXME: Move into request model.
      server.close_pull_request(server.source_repo, request.number)
      unless server.request_exists?(request.number, 'open')
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
        if server.request_exists_from_branch?(upstream)
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
      request = server.request(number) if number

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

  end

end
