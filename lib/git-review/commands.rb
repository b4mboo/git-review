module GitReview

  module Commands

    include Internals
    extend self

    attr_accessor :args

    # List all pending requests.
    def list
      requests = github.current_requests_full.reject { |request|
        # find only pending (= unmerged) requests and output summary
        # explicitly look for local changes Github does not yet know about
        local.merged?(request.head.sha)
      }
      requests.reverse! if next_arg == '--reverse'
      source = local.source
      if requests.empty?
        puts "No pending requests for '#{source}'."
      else
        puts "Pending requests for '#{source}':"
        puts "ID      Updated    Comments  Title"
        requests.each { |request| print_request(request) }
      end
    end

    # Show details for a single request.
    def show
      request = get_request_or_return
      # determine whether to show full diff or just stats
      option = next_arg == '--full' ? '' : '--stat '
      diff = "diff --color=always #{option}HEAD...#{request.head.sha}"
      print_request_details(request)
      puts git_call(diff)
      print_request_discussions(request)
    end

    # Open a browser window and review a specified request.
    def browse
      request = get_request_or_return
      Launchy.open(request.html_url) if request
    end

    # Checkout a specified request's changes to your local repository.
    def checkout
      request = get_request_or_return
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
      request = get_request_or_return
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
      request = get_request_or_return
      if request.head.repo
        option = next_arg  # FIXME: What options are allowed here?
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
      else
        print_repo_deleted(request)
      end
    end

    # Close a specified request.
    def close
      request = get_request_or_return
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
      if next_arg == '--new' || !local.on_feature_branch?
        local_branch = move_uncommitted_changes(local.target_branch)
      else
        local_branch = original_branch
      end
      [original_branch, local_branch]
    end

    # Create a new request.
    # TODO: Support creating requests to other repositories and branches (like
    #   the original repo, this has been forked from).
    def create
      to_upstream = next_arg == '--upstream'
      # prepare original_branch and local_branch
      original_branch, local_branch = prepare
      # don't create request with uncommitted changes in current branch
      unless git_call('diff HEAD').empty?
        puts 'You have uncommitted changes.'
        puts 'Please stash or commit before creating the request.'
        return
      end
      if git_call("cherry #{local.target_branch}").empty?
        puts 'Nothing to push to remote yet. Commit something first.'
      else
        # push latest commits to the remote branch (create if necessary)
        git_call("push --set-upstream origin #{local_branch}", debug_mode, true)
        create_pull_request(to_upstream)
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
          arg = next_arg
          arg == '--all' ? local.clean_all : local.clean_single(arg)
        when 2
          # git review clean ID --force
          local.clean_single(next_arg, next_arg == '--force')
        else
          raise ::GitReview::InvalidArgumentError
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
  create [--upstream]       Create a new request.
  clean <ID> [--force]      Delete a request\'s remote and local branches.
  clean --all               Delete all obsolete branches.
HELP_TEXT
    end

  private

    def print_request(request)
      date_string = format_time(request.updated_at)
      comments_count = request.comments.to_i + request.review_comments.to_i
      line = format_text(request.number, 8)
      line << format_text(date_string, 11)
      line << format_text(comments_count, 10)
      line << format_text(request.title, 91)
      puts line
    end

    def print_request_details(request)
      comments_count = request.comments.to_i + request.review_comments.to_i
      puts 'ID        : ' + request.number.to_s
      puts 'Label     : ' + request.head.label
      puts 'Updated   : ' + format_time(request.updated_at)
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
      puts github.discussion(request.number)
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
      if (branch_name = next_arg).nil?
        puts 'Please provide a name for the branch:'
        branch_name = gets.chomp
      end
      branch_name.gsub(/\W+/, '_').downcase
    end

    # move uncommitted changes from target branch to local branch
    # @return [String] the new local branch uncommitted changes are moved to
    def move_uncommitted_changes(target_branch)
      local_branch = "review_#{Time.now.strftime("%y%m%d")}_#{get_branch_name}"
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

    def create_pull_request(to_upstream=false)
      # head is in the form of 'user:branch'
      head = "#{github.github.login}:#{local.source_branch}"
      # if to send a pull request to upstream repo, get the parent as target
      target_repo = if to_upstream
                      github.repository(github.source_repo).parent.full_name
                    else
                      local.target_repo
                    end
      base = local.target_branch
      # gather information before creating pull request
      last_id = github.pull_requests(target_repo).
          collect(&:number).sort.last.to_i
      title, body = create_title_and_body(base)
      # create the actual pull request
      github.create_pull_request(
          target_repo, base, head, title, body
      )
      # switch back to target_branch and check for success
      git_call("checkout #{base}")
      new_request = github.pull_requests(target_repo).
          find { |r| r.title == title }
      if new_request
        current_number = new_request.number
        if current_number > last_id
          puts "Successfully created new request ##{current_number}"
          puts "https://github.com/#{target_repo}/pull/#{current_number}"
        end
      end
    end


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
      @args.is_a?(Array) ? @args.shift : @args
    end

    def get_request_or_return
      request_number = next_arg || (raise ::GitReview::InvalidRequestIDError)
      request = github.request_exists?(request_number)
      request || (raise ::GitReview::InvalidRequestIDError)
    end

  end

end

