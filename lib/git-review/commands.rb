module GitReview

  module Commands

    include Internals
    extend self

    attr_accessor :args

    # List all pending requests.
    def list
      output = github.current_requests_full.collect { |request|
        # find only pending (= unmerged) requests and output summary
        # explicitly look for local changes Github does not yet know about
        next if local.merged?(request.head.sha)
        date_string = format_time(request.updated_at)
        comments_count = request.comments.to_i + request.review_comments.to_i
        line = format_text(request.number, 8)
        line << format_text(date_string, 11)
        line << format_text(comments_count, 10)
        line << format_text(request.title, 91)
      }.compact
      source = local.source
      if output.empty?
        puts "No pending requests for '#{source}'."
      else
        output.reverse! if next_arg == '--reverse'
        puts "Pending requests for '#{source}':\n" +
             "ID      Updated    Comments  Title"
        output.each { |line| puts line }
      end
    end

    # Show details for a single request.
    def show
      request_number = next_arg
      request = github.request_exists?(request_number)
      unless request
        puts 'Please specify a valid ID.'
        return
      end
      # determine whether to show full diff or just stats
      option = next_arg == '--full' ? '' : '--stat '
      diff = "diff --color=always #{option}HEAD...#{request.head.sha}"
      comments_count = request.comments.to_i + request.review_comments.to_i
      puts 'ID        : ' + request.number.to_s
      puts 'Label     : ' + request.head.label
      puts 'Updated   : ' + format_time(request.updated_at)
      puts 'Comments  : ' + comments_count.to_s
      puts
      puts request.title
      puts
      puts request.body unless request.body.empty?
      puts
      puts git_call(diff)
      puts
      puts 'Progress  :'
      puts
      puts github.discussion(request_number)
    end

    # Open a browser window and review a specified request.
    def browse
      request_number = next_arg
      request = github.request_exists?(request_number)
      unless request
        puts 'Please specify a valid ID.'
        return
      end
      Launchy.open(request.html_url) if request
    end

    # Checkout a specified request's changes to your local repository.
    def checkout
      request_number = next_arg
      request = github.request_exists?(request_number)
      unless request
        puts 'Please specify a valid ID.'
        return
      end
      puts 'Checking out changes to your local repository.'
      puts 'To get back to your original state, just run:'
      puts
      puts '  git checkout master'
      puts
      if next_arg == '--branch'
        git_call("checkout #{request.head.ref}")
      else
        git_call("checkout pr/#{request.number}")
      end
    end

    # Add an approving comment to the request.
    def approve
      request_number = next_arg
      request = github.request_exists?(request_number)
      unless request
        puts 'Please specify a valid ID.'
        return
      end
      repo = github.source_repo
      # TODO: Make this configurable.
      comment = 'Reviewed and approved.'
      response = github.add_comment(repo, request.number, comment)
      if response[:body] == comment
        puts 'Successfully approved request.'
      else
        puts response[:message]
      end
    end

    # Accept a specified request by merging it into master.
    def merge
      request_number = next_arg
      request = github.request_exists?(request_number)
      unless request
        puts 'Please specify a valid ID.'
        return
      end
      # FIXME: What options are allowed here?
      option = next_arg
      unless request.head.repo
        # someone deleted the source repo
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
        return false
      end
      message = "Accept request ##{request.number} " +
          "and merge changes into \"#{local.target}\""
      command = "merge #{option} -m '#{message}' #{request.head.sha}"
      puts
      puts "Request title:"
      puts "  #{request.title}"
      puts
      puts "Merge command:"
      puts "  git #{command}"
      puts
      puts git_call(command)
    end


    # Close a specified request.
    def close
      request_number = next_arg
      request = github.request_exists?(request_number, 'open')
      unless request
        puts 'Please specify a valid ID.'
        return
      end
      repo = github.source_repo
      github.close_issue(repo, request.number)
      unless github.request_exists?('open', request.number)
        puts 'Successfully closed request.'
      end
    end


    # Prepare local repository to create a new request.
    # People should work on local branches, but especially for single commit
    #   changes, more often than not, they don't. Therefore we create a branch
    #   for them, to be able to use code review the way it is intended.
    # @return [Array(String, String)] the original branch and the local branch
    def prepare
      # remember original branch the user was currently working on
      original_branch = local.source_branch
      target_branch = local.target_branch

      if next_arg == '--new' || !local.on_feature_branch?
        # ask for branch name if not provided
        if (branch_name = next_arg).nil?
          puts 'Please provide a name for the branch:'
          branch_name = gets.chomp
        end
        sanitized_name = branch_name.gsub(/\W+/, '_').downcase
        # create the new branch (as a copy of the current one)
        local_branch = "review_#{Time.now.strftime("%y%m%d")}_#{sanitized_name}"
        git_call("checkout -b #{local_branch}")
        # make sure we are on the feature branch
        if local.source_branch == local_branch
          # stash any uncommitted changes
          save_uncommitted_changes = local.uncommitted_changes?
          git_call('stash') if save_uncommitted_changes
          # go back to master and get rid of pending commits (as these are now
          #   on the new branch)
          git_call("checkout #{target_branch}")
          git_call("reset --hard origin/#{target_branch}")
          git_call("checkout #{local_branch}")
          git_call('stash pop') if save_uncommitted_changes
        end
      else
        local_branch = original_branch
      end
      [original_branch, local_branch]
    end


    # Create a new request.
    # TODO: Support creating requests to other repositories and branches (like
    #   the original repo, this has been forked from).
    def create
      # prepare original_branch and local_branch
      original_branch, local_branch = prepare
      target_branch = local.target_branch
      target_repo = local.target_repo
      source_branch = local.source_branch
      # don't create request with uncommitted changes in current branch
      unless git_call('diff HEAD').empty?
        puts 'You have uncommitted changes.'
        puts 'Please stash or commit before creating the request.'
        return
      end
      if git_call("cherry #{target_branch}").empty?
        puts 'Nothing to push to remote yet. Commit something first.'
      else
        # push latest commits to the remote branch (and by that, create it
        #   if necessary)
        git_call("push --set-upstream origin #{local_branch}", debug_mode, true)
        # gather information before creating pull request
        requests = github.current_requests
        last_id = requests.collect(&:number).sort.last.to_i
        title, body = create_title_and_body(target_branch)
        # create the actual pull request
        github.create_pull_request(
            target_repo, target_branch, source_branch, title, body
        )
        # switch back to target_branch and check for success
        git_call("checkout #{target_branch}")
        requests = github.current_requests
        potential_new_request = requests.find { |r| r.title == title }
        if potential_new_request
          current_number = potential_new_request.number
          if current_number > last_id
            puts "Successfully created new request ##{current_number}"
            puts "https://github.com/#{target_repo}/pull/#{current_number}"
          end
        end
        # return to the user's original branch
        # FIXME: keep track of original branch etc
        git_call("checkout #{original_branch}")
      end
    end


    # delete obsolete branches (left over from already closed requests)
    def clean
      # pruning is needed to remove deleted branches from your local track
      git_call('remote prune origin')
      # determine strategy to clean.
      case @args.size
        when 1
          if @args.first == '--all'
            # git review clean --all
            local.clean_all
          else
            # git review clean ID
            local.clean_single(@args.first)
          end
        when 2
          # git review clean ID --force
          local.clean_single(@args.first, @args.last == '--force')
        else
          puts 'Argument error. Please provide either an ID or "--all".'
      end
    end


    # Start a console session (used for debugging).
    def console
      # TODO: Debugger for Ruby 2.0?
      puts 'Entering debug console.'
      #request_exists?
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
  prepare [--new]           Creates a new local branch for a request.
  create                    Create a new request.
  clean <ID> [--force]      Delete a request\'s remote and local branches.
  clean --all               Delete all obsolete branches.
HELP_TEXT
    end

  private

    # @return [Array(String, String)] the title and the body of pull request
    def create_title_and_body(target_branch)
      source = local.source
      login = github.github.login
      commits = git_call("log --format='%H' HEAD...#{target_branch}").
          lines.count
      puts "commits: #{commits}"
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

      tmpfile = Tempfile.new('git-review')
      tmpfile.write(title + "\n\n" + body)
      tmpfile.flush
      editor = ENV['TERM_EDITOR'] || ENV['EDITOR']
      unless editor
        warn "Please set $EDITOR or $TERM_EDITOR in your .bash_profile."
      end

      system("#{editor || 'open'} #{tmpfile.path}")

      tmpfile.rewind
      lines = tmpfile.read.lines.to_a
      puts lines.inspect
      title = lines.shift.chomp
      lines.shift if lines[0].chomp.empty?

      body = lines.join

      tmpfile.unlink

      [title, body]
    end

    def github
      @github ||= ::GitReview::Github.instance
    end

    def local
      @local ||= ::GitReview::Local.instance
    end

    def next_arg
      @args.shift
    end

  end

end

