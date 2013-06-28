module GitReview

  module Commands

    extend self

    attr_accessor :args

    # List all pending requests.
    def list
      output = @current_requests.collect do |request|
        details = @github.pull_request(source_repo, request.number)
        # Find only pending (= unmerged) requests and output summary.
        # Explicitly look for local changes (that GitHub does not yet know about).
        next if merged?(request.head.sha)
        line = format_text(request.number, 8)
        date_string = format_time(request.updated_at)
        line << format_text(date_string, 11)
        line << format_text(details.comments + details.review_comments, 10)
        line << format_text(request.title, 91)
        line
      end
      output.compact!
      if output.empty?
        puts "No pending requests for '#{source}'."
      else
        puts "Pending requests for '#{source}':"
        puts 'ID      Updated    Comments  Title'
        output.reverse! if @args.shift == '--reverse'
        output.each { |line| puts line }
      end
    end


    # Show details for a single request.
    def show
      return unless request_exists?
      # Determine whether to show full diff or just stats.
      option = @args.shift == '--full' ? '' : '--stat '
      diff = "diff --color=always #{option}HEAD...#{@current_request.head.sha}"
      # TODO: Move to comment calculations to request class.
      comment_count = @current_request.comments + @current_request.review_comments
      puts 'ID        : ' + @current_request.number.to_s
      puts 'Label     : ' + @current_request.head.label
      puts 'Updated   : ' + format_time(@current_request.updated_at)
      puts 'Comments  : ' + comment_count.to_s
      puts
      puts @current_request.title
      puts
      puts @current_request.body
      puts
      puts git_call diff
      puts
      puts "Progress  :"
      puts
      discussion
    end


    # Open a browser window and review a specified request.
    def browse
      Launchy.open @current_request.html_url if request_exists?
    end


    # Checkout a specified request's changes to your local repository.
    def checkout
      return unless request_exists?
      create_local_branch = @args.shift == '--branch' ? '' : 'origin/'
      puts 'Checking out changes to your local repository.'
      puts 'To get back to your original state, just run:'
      puts
      puts '  git checkout master'
      puts
      git_call "checkout #{create_local_branch}#{@current_request.head.ref}"
    end


    # Add an approving comment to the request.
    def approve
      return unless request_exists?
      # TODO: Make this configurable.
      comment = 'Reviewed and approved.'
      response = @github.add_comment source_repo, @current_request.number, comment
      if response[:body] == comment
        puts 'Successfully approved request.'
      else
        puts response[:message]
      end
    end


    # Accept a specified request by merging it into master.
    def merge
      return unless request_exists?
      # FIXME: What options are allowed here?
      option = @args.shift
      unless @current_request.head.repo
        # Someone deleted the source repo.
        user = @current_request.head.user.login
        url = @current_request.patch_url
        puts "Sorry, #{user} deleted the source repository."
        puts 'git-review doesn\'t support this.'
        puts 'Tell the contributor not to do this.'
        puts
        puts 'You can still manually patch your repo by running:'
        puts
        puts "  curl #{url} | git am"
        puts
        return false
      end
      message = "Accept request ##{@current_request.number}" +
        " and merge changes into \"#{target}\""
      command = "merge #{option} -m '#{message}' #{@current_request.head.sha}"
      puts
      puts 'Request title:'
      puts '  ' + @current_request.title
      puts
      puts 'Merge command:'
      puts "  git #{command}"
      puts
      puts git_call command
    end


    # Close a specified request.
    def close
      return unless request_exists?
      @github.close_issue source_repo, @current_request.number
      unless request_exists?('open', @current_request.number)
        puts 'Successfully closed request.'
      end
    end


    # Prepare local repository to create a new request.
    # Sets @local_branch.
    def prepare
      # Remember original branch the user was currently working on.
      @original_branch = source_branch
      # People should work on local branches, but especially for single commit
      # changes, more often than not, they don't. Therefore we create a branch for
      # them, to be able to use code review the way it is intended.
      if on_feature_branch?
        @local_branch = @original_branch
      else
        # Unless a branch name is already provided, ask for one.
        if (branch_name = @args.shift).nil?
          puts 'Please provide a name for the branch:'
          branch_name = gets.chomp
        end
        sanitized_name = branch_name.gsub(/\W+/, '_').downcase
        # Create the new branch (as a copy of the current one).
        @local_branch = "review_#{Time.now.strftime("%y%m%d")}_#{sanitized_name}"
        git_call "checkout -b #{@local_branch}"
        # Have we reached the feature branch?
        if source_branch == @local_branch
          # Stash any uncommitted changes.
          save_uncommitted_changes = !git_call('diff HEAD').empty?
          git_call('stash') if save_uncommitted_changes
          # Go back to master and get rid of pending commits (as these are now on
          # the new branch).
          git_call "checkout #{target_branch}"
          git_call "reset --hard origin/#{target_branch}"
          git_call "checkout #{@local_branch}"
          git_call('stash pop') if save_uncommitted_changes
        end
      end
    end


    # Create a new request.
    # TODO: Support creating requests to other repositories and branches (like the
    # original repo, this has been forked from).
    def create
      # Prepare @local_branch.
      prepare
      # Don't create request with uncommitted changes in current branch.
      unless git_call('diff HEAD').empty?
        puts 'You have uncommitted changes.'
        puts 'Please stash or commit before creating the request.'
        return
      end
      unless git_call("cherry #{target_branch}").empty?
        # Push latest commits to the remote branch (and by that, create it
        # if necessary).
        git_call "push --set-upstream origin #{@local_branch}", debug_mode, true
        # Gather information.
        last_id = @current_requests.collect(&:number).sort.last.to_i
        title, body = create_title_and_body(target_branch)
        # Create the actual pull request.
        @github.create_pull_request(
          target_repo, target_branch, source_branch, title, body
        )
        # Switch back to target_branch and check for success.
        git_call "checkout #{target_branch}"
        update
        potential_new_request = @current_requests.find { |r| r.title == title }
        if potential_new_request
          current_id = potential_new_request.number
          if current_id > last_id
            puts "Successfully created new request ##{current_id}"
            puts "https://github.com/#{target_repo}/pull/#{current_id}"
          end
        end
        # Return to the user's original branch.
        git_call "checkout #{@original_branch}"
      else
        puts 'Nothing to push to remote yet. Commit something first.'
      end
    end


    # delete obsolete branches (left over from already closed requests).
    def clean
      # pruning is needed to remove deleted branches from your local track.
      git_call 'remote prune origin'
      # determine strategy to clean.
      case @args.size
        when 1
          if @args.first == '--all'
            # git review clean --all
            clean_all
          else
            # git review clean ID
            clean_single(@args.first)
          end
        when 2
          # git review clean ID --force
          clean_single(@args.first, @args.last == '--force')
        else
          raise ::GitReview::Errors::InvalidArgumentError,
                'Argument error. Please provide either an ID or "--all".'
      end
    end


    # Start a console session (used for debugging).
    def console
      puts 'Entering debug console.'
      request_exists?
      require 'ruby-debug'
      Debugger.start
      debugger
      puts 'Leaving debug console.'
    end


    # Show a quick reference of available commands.
    def help
      puts <<HELP_TEXT
Usage: git review <command>
Manage review workflow for projects hosted on GitHub (using pull requests).
Available commands:
  list [--reverse]          List all pending requests.
  show <ID> [--full]        Show details for a single request.
  browse <ID>               Open a browser window and review a request.
  checkout <ID> [--branch]  Checkout a request\'s changes to your local repo.
  approve <ID>              Add an approving comment to a request.
  merge <ID>                Accept a request by merging it into master.
  close <ID>                Close a request.
  prepare                   Creates a new local branch for a request.
  create                    Create a new request.
  clean <ID> [--force]      Delete a request\'s remote and local branches.
  clean --all               Delete all obsolete branches.
HELP_TEXT
    end

  end

end

