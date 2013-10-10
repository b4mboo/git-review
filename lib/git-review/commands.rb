module GitReview

  module Commands

    include ::GitReview::Helpers
    extend self

    # List all pending requests.
    def list(reverse = false)
      requests = server.current_requests_full.reject do |request|
        # Find only pending (= unmerged) requests and output summary.
        # Explicitly look for local changes git does not yet know about.
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
        print_repo_deleted(request)
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
    # People should work on local branches, but especially for single commit
    #   changes, more often than not, they don't. Therefore we create a branch
    #   for them, to be able to use code review the way it is intended.
    # @return [Array(String, String)] the original branch and the local branch
    def prepare(new=false, name=nil)
      # remember original branch the user was currently working on
      original_branch = local.source_branch
      if new || !local.on_feature_branch?
        local_branch = move_uncommitted_changes(local.target_branch, name)
      else
        local_branch = original_branch
      end
      [original_branch, local_branch]
    end

    # Create a new request.
    # TODO: Support creating requests to other repositories and branches (like
    #   the original repo, this has been forked from).
    def create(upstream=false)
      # prepare original_branch and local_branch
      original_branch, local_branch = prepare
      # don't create request with uncommitted changes in current branch
      if local.uncommitted_changes?
        puts 'You have uncommitted changes.'
        puts 'Please stash or commit before creating the request.'
        return
      end
      if local.new_commits?(upstream)
        # feature branch differs from local or upstream master
        if server.request_exists_for_branch?(upstream)
          puts 'A pull request already exists for this branch.'
          puts 'Please update the request directly using `git push`.'
          return
        end
        # push latest commits to the remote branch (create if necessary)
        git_call("push --set-upstream origin #{local_branch}", debug_mode, true)
        create_pull_request(upstream)
        # return to the user's original branch
        # FIXME: keep track of original branch etc
        git_call("checkout #{original_branch}")
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

    def request_summary_line(request)
      line = request.number.review_ljust(8)
      line << request.updated_at.review_time.review_ljust(11)
      line << server.comments_count(request).review_ljust(10)
      line << request.title.review_ljust(91)
      line
    end

    def print_requests(requests, reverse=false)
      # put all output lines in a hash first, keyed by request number
      # this is to make sure the order is still correct even if we use
      #   multi-threading to retrieve the requests
      output = {}
      requests.each { |req| output[req.number] = request_summary_line(req) }
      numbers = output.keys.sort
      numbers.reverse! if reverse
      numbers.each do |n|
        puts output[n]
      end
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
      branch_name = gets.chomp
      branch_name.gsub(/\W+/, '_').downcase
    end

    # @return [String] the complete feature branch name
    def create_feature_name(new_branch)
      "review_#{Time.now.strftime("%y%m%d")}_#{new_branch}"
    end

    # move uncommitted changes from target branch to local branch
    # @return [String] the new local branch uncommitted changes are moved to
    def move_uncommitted_changes(target_branch, new_branch)
      new_branch ||= get_branch_name
      local_branch = create_feature_name(new_branch)
      git_call("checkout -b #{local_branch}")
      # make sure we are on the feature branch
      if local.source_branch == local_branch
        # stash any uncommitted changes
        save_uncommitted_changes = local.uncommitted_changes?
        git_call('stash') if save_uncommitted_changes
        # go back to target and get rid of pending commits
        git_call("checkout #{target_branch}")
        git_call("reset --hard origin/#{target_branch}")
        git_call("checkout #{local_branch}")
        git_call('stash pop') if save_uncommitted_changes
        local_branch
      end
    end

    # FIXME: move create pull request into provider
    def create_pull_request(to_upstream=false)
      target_repo = local.target_repo(to_upstream)
      head = local.head
      base = local.target_branch
      title, body = create_title_and_body(base)

      # gather information before creating pull request
      lastest_number = server.latest_request_number(target_repo)

      # create the actual pull request
      server.create_pull_request(target_repo, base, head, title, body)
      # switch back to target_branch and check for success
      git_call("checkout #{base}")

      # make sure the new pull request is indeed created
      new_number = server.request_number_by_title(title, target_repo)
      if new_number && new_number > lastest_number
        puts "Successfully created new request ##{new_number}"
        puts server.request_url_for target_repo, new_number
      else
        puts "Pull request was not created for #{target_repo}."
      end
    end


    # @return [Array(String, String)] the title and the body of pull request
    def create_title_and_body(target_branch)
      source = local.source
      login = server.login
      commits = git_call("log --format='%H' HEAD...#{target_branch}").
          lines.count
      puts "Commits: #{commits}"
      if commits == 1
        # we can create a really specific title and body
        title = git_call("log --format='%s' HEAD...#{target_branch}").chomp
        body  = git_call("log --format='%b' HEAD...#{target_branch}").chomp
      else
        title = "[Review] Request from '#{login}' @ '#{source}'"
        body  = "Please review the following changes:\n"
        body += git_call("log --oneline HEAD...#{target_branch}").
            lines.map{|l| "  * #{l.chomp}"}.join("\n")
      end
      edit_title_and_body(title, body)
    end

    # TODO: refactor
    def edit_title_and_body(title, body)
      tmpfile = Tempfile.new('git-review')
      tmpfile.write(title + "\n\n" + body)
      tmpfile.flush
      editor = ENV['TERM_EDITOR'] || ENV['EDITOR']
      unless editor
        warn 'Please set $EDITOR or $TERM_EDITOR in your .bash_profile.'
      end

      system("#{editor || 'open'} #{tmpfile.path}")

      tmpfile.rewind
      lines = tmpfile.read.lines.to_a
      #puts lines.inspect
      title = lines.shift.chomp
      lines.shift if lines[0].chomp.empty?
      body = lines.join
      tmpfile.unlink
      [title, body]
    end

    def server
      @server ||= ::GitReview::Server.instance
    end

    def local
      @local ||= ::GitReview::Local.instance
    end

  end

end
