require_relative 'internals'

module GitReview

  module Commands

    include Internals
    extend self

    attr_accessor :args

    # List all pending requests.
    def list
      github = ::GitReview::Github.instance
      source_repo = github.source_repo
      source = github.source
      output = github.current_requests.collect do |request|
        details = github.pull_request(source_repo, request.number)
        # Find only pending (= unmerged) requests and output summary.
        # Explicitly look for local changes (that GitHub does not yet know about).
        next if ::GitReview::Local.instance.merged?(request.head.sha)
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
      github = ::GitReview::Github.instance
      request_id = @args.shift
      if github.request_exists?('open', request_id)
        current_request = github.pull_request(github.source_repo, request_id)
      else
        return
      end
      # Determine whether to show full diff or just stats.
      option = @args.shift == '--full' ? '' : '--stat '
      diff = "diff --color=always #{option}HEAD...#{current_request.head.sha}"
      # TODO: Move to comment calculations to request class.
      puts current_request.comments_count
      puts 'ID        : ' + current_request.number.to_s
      puts 'Label     : ' + current_request.head.label
      puts 'Updated   : ' + format_time(current_request.updated_at)
      puts 'Comments  : ' + current_request.comments_count.to_s
      puts
      puts current_request.title
      puts
      puts current_request.body
      puts
      puts git_call diff
      puts
      puts 'Progress  :'
      puts
      discussion
    end


    # Open a browser window and review a specified request.
    def browse
      github = ::GitReview::Github.instance
      request_id = @args.shift
      if github.request_exists?('open', request_id)
        Launchy.open github.get_request('open', request_id).html_url
      end
    end


    # Checkout a specified request's changes to your local repository.
    def checkout
      github = ::GitReview::Github.instance
      request_id = @args.shift
      return unless github.request_exists?('open', request_id)
      request = github.get_request('open', request_id)
      create_local_branch = @args.shift == '--branch' ? '' : 'origin/'
      puts 'Checking out changes to your local repository.'
      puts 'To get back to your original state, just run:'
      puts
      puts '  git checkout master'
      puts
      git_call "checkout #{create_local_branch}#{request.head.ref}"
    end


    # Add an approving comment to the request.
    def approve
      github = ::GitReview::Github.instance
      request_id = @args.shift
      return unless github.request_exists?('open', request_id)
      request = github.get_request('open', request_id)
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
      github = ::GitReview::Github.instance
      request_id = @args.shift
      return unless github.request_exists?('open', request_id)
      request = github.get_request('open', request_id)
      # FIXME: What options are allowed here?
      option = @args.shift
      unless request.head.repo
        # Someone deleted the source repo.
        user = request.head.user.login
        url = request.patch_url
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
      message = "Accept request ##{request.number}" +
        " and merge changes into \"#{::GitReview::Local.instance.target}\""
      command = "merge #{option} -m '#{message}' #{request.head.sha}"
      puts
      puts 'Request title:'
      puts '  ' + request.title
      puts
      puts 'Merge command:'
      puts "  git #{command}"
      puts
      puts git_call command
    end


    # Close a specified request.
    def close
      github = ::GitReview::Github.instance
      request_id = @args.shift
      return unless github.request_exists?('open', request_id)
      request = github.get_request('open', request_id)
      repo = github.source_repo
      github.close_issue(repo, request.number)
      unless github.request_exists?('open', request.number)
        puts 'Successfully closed request.'
      end
    end


    # Prepare local repository to create a new request.
    # Return original_branch and local_branch.
    def prepare
      # Remember original branch the user was currently working on.
      local = ::GitReview::Local.instance
      target_branch = local.target_branch
      original_branch = local.source_branch
      # People should work on local branches, but especially for single commit
      # changes, more often than not, they don't. Therefore we create a branch
      # for them, to be able to use code review the way it is intended.
      if @args.shift == '--new' || !local.on_feature_branch?
        # Unless a branch name is already provided, ask for one.
        if (branch_name = @args.shift).nil?
          puts 'Please provide a name for the branch:'
          branch_name = gets.chomp
        end
        sanitized_name = branch_name.gsub(/\W+/, '_').downcase
        # Create the new branch (as a copy of the current one).
        local_branch = "review_#{Time.now.strftime("%y%m%d")}_#{sanitized_name}"
        git_call "checkout -b #{local_branch}"
        # Have we reached the feature branch?
        if local.source_branch == local_branch
          # Stash any uncommitted changes.
          save_uncommitted_changes = !git_call('diff HEAD').empty?
          git_call('stash') if save_uncommitted_changes
          # Go back to master and get rid of pending commits (as these are now
          # on the new branch).
          git_call "checkout #{target_branch}"
          git_call "reset --hard origin/#{target_branch}"
          git_call "checkout #{local_branch}"
          git_call('stash pop') if save_uncommitted_changes
        end
      else
        local_branch = original_branch
      end
      [original_branch, local_branch]
    end


    # Create a new request.
    # TODO: Support creating requests to other repositories and branches (like
    # the original repo, this has been forked from).
    def create
      # Prepare original_branch and local_branch.
      original_branch, local_branch = prepare
      local = ::GitReview::Local.instance
      target_branch = local.target_branch
      target_repo = local.target_repo
      source_branch = local.source_branch
      # Don't create request with uncommitted changes in current branch.
      unless git_call('diff HEAD').empty?
        puts 'You have uncommitted changes.'
        puts 'Please stash or commit before creating the request.'
        return
      end
      if git_call("cherry #{target_branch}").empty?
        puts 'Nothing to push to remote yet. Commit something first.'
      else
        # Push latest commits to the remote branch (and by that, create it
        # if necessary).
        git_call("push --set-upstream origin #{local_branch}", debug_mode, true)
        # Gather information.
        github = ::GitReview::Github.instance
        requests = github.current_requests
        last_id = requests.collect(&:number).sort.last.to_i
        title, body = create_title_and_body(target_branch)
        # Create the actual pull request.
        github.create_pull_request(
            target_repo, target_branch, source_branch, title, body
        )
        # Switch back to target_branch and check for success.
        git_call("checkout #{target_branch}")
        github.update
        potential_new_request = requests.find { |r| r.title == title }
        if potential_new_request
          current_id = potential_new_request.number
          if current_id > last_id
            puts "Successfully created new request ##{current_id}"
            puts "https://github.com/#{target_repo}/pull/#{current_id}"
          end
        end
        # Return to the user's original branch.
        # FIXME: keep track of original branch etc
        git_call "checkout #{original_branch}"
      end
    end


    # delete obsolete branches (left over from already closed requests).
    def clean
      local_repo = ::GitReview::Local.instance
      # pruning is needed to remove deleted branches from your local track.
      git_call('remote prune origin')
      # determine strategy to clean.
      case @args.size
        when 1
          if @args.first == '--all'
            # git review clean --all
            local_repo.clean_all
          else
            # git review clean ID
            local_repo.clean_single(@args.first)
          end
        when 2
          # git review clean ID --force
          local_repo.clean_single(@args.first, @args.last == '--force')
        else
          raise ::GitReview::Errors::InvalidArgumentError,
                'Argument error. Please provide either an ID or "--all".'
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

    # Returns an array where the 1st item is the title and the 2nd one is the body
    def create_title_and_body(target_branch)
      local = ::GitReview::Local.instance
      source = local.source
      git_config = local.config
      commits = git_call("log --format='%H' HEAD...#{target_branch}").
          lines.count
      puts "commits: #{commits}"
      if commits == 1
        # we can create a really specific title and body
        title = git_call("log --format='%s' HEAD...#{target_branch}").chomp
        body  = git_call("log --format='%b' HEAD...#{target_branch}").chomp
      else
        title = "[Review] Request from '#{git_config['github.login']}'" +
            " @ '#{source}'"
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

  end

end

