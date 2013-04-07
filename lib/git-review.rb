# Octokit is used to access GitHub's API.
require 'octokit'
# Launchy is used in 'browse' to open a browser.
require 'launchy'
# Time is used to parse time strings from git back into Time objects.
require 'time'
# tempfile is used to create a temporary file containing PR's title and body.
# This file is going to be edited by the system editor.
require 'tempfile'
# This file provides the OAuthHelper module which is used to create a oauth token/
require_relative 'oauth_helper'
# Setting class
require_relative 'settings'

require 'accessible'
require 'nestable'
require 'user'
require 'commit'
require 'request'

# A custom error to raise, if we know we can't go on.
class UnprocessableState < StandardError
end


class GitReview
  include OAuthHelper

  ## COMMANDS ##

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
    # FIXME: Update discussion output to work with APIv3.
    # puts
    # puts "Progress  :"
    # puts
    # discussion
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
    @github.close_issue source_repo, @current_request['number']
    puts 'Successfully closed request.' unless request_exists?('open', @current_request['number'])
  end


  # Prepare local repository to create a new request.
  # Sets @local_branch.
  def prepare
    # Remember original branch the user was currently working on.
    @original_branch = source_branch
    # People should work on local branches, but especially for single commit changes,
    # more often than not, they don't. Therefore we create a branch for them,
    # to be able to use code review the way it is intended.
    if @original_branch == target_branch
      # Unless a branch name is already provided, ask for one.
      if (branch_name = @args.shift).nil?
        puts 'Please provide a name for the branch:'
        branch_name = gets.chomp.gsub(/\W+/, '_').downcase
      end
      # Create the new branch (as a copy of the current one).
      @local_branch = "review_#{Time.now.strftime("%y%m%d")}_#{branch_name}"
      git_call "checkout -b #{@local_branch}"
      if source_branch == @local_branch
        # Stash any uncommitted changes.
        git_call('stash') if (save_uncommitted_changes = !git_call('diff HEAD').empty?)
        # Go back to master and get rid of pending commits (as these are now on the new branch).
        git_call "checkout #{target_branch}"
        git_call "reset --hard origin/#{target_branch}"
        git_call "checkout #{@local_branch}"
        git_call('stash pop') if save_uncommitted_changes
      end
    else
      @local_branch = @original_branch
    end
  end


  # Create a new request.
  # TODO: Support creating requests to other repositories and branches (like the original repo, this has been forked from).
  def create
    # Prepare @local_branch.
    prepare
    # Don't create request with uncommitted changes in current branch.
    unless git_call('diff HEAD').empty?
      puts 'You have uncommitted changes. Please stash or commit before creating the request.'
      return
    end
    unless git_call("cherry #{target_branch}").empty?
      # Push latest commits to the remote branch (and by that, create it if necessary).
      git_call "push --set-upstream origin #{@local_branch}", debug_mode, true
      # Gather information.
      last_request_id = @current_requests.collect { |req| req['number'] }.sort.last.to_i
      title, body = create_title_and_body(target_branch)
      # Create the actual pull request.
      @github.create_pull_request target_repo, target_branch, source_branch, title, body
      # Switch back to target_branch and check for success.
      git_call "checkout #{target_branch}"
      update
      potential_new_request = @current_requests.find { |req| req['title'] == title }
      if potential_new_request and potential_new_request['number'] > last_request_id
        puts "Successfully created new request ##{potential_new_request['number']}"
        puts File.join("https://github.com", target_repo, "pull", potential_new_request['number'].to_s)
      end
      # Return to the user's original branch.
      git_call "checkout #{@original_branch}"
    else
      puts 'Nothing to push to remote yet. Commit something first.'
    end
  end


  # Deletes obsolete branches (left over from already closed requests).
  def clean
    # Pruning is needed to remove already deleted branches from your local track.
    git_call 'remote prune origin'
    # Determine strategy to clean.
    case @args.size
      when 0
        puts 'Argument missing. Please provide either an ID or the option "--all".'
      when 1
        if @args.first == '--all'
          # git review clean --all
          clean_all
        else
          # git review clean ID
          clean_single
        end
      when 2
        # git review clean ID --force
        clean_single(@args.last == '--force')
      else
        puts 'Too many arguments.'
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


  private

  # Setup variables and call actual commands.
  def initialize(args = [])
    @args = args
    command = args.shift
    if command and self.respond_to?(command)
      @user, @repo = repo_info
      return unless @user && @repo && configure_github_access
      update unless command == 'clean'
      self.send command
    else
      unless command.nil? or command.empty? or %w(help -h --help).include?(command)
        puts "git-review: '#{command}' is not a valid command.\n\n"
      end
      help
    end
  rescue UnprocessableState
    puts 'Execution of git-review command stopped.'
  end


  # Show a quick reference of available commands.
  def help
    puts 'Usage: git review <command>'
    puts 'Manage review workflow for projects hosted on GitHub (using pull requests).'
    puts
    puts 'Available commands:'
    puts '  list [--reverse]          List all pending requests.'
    puts '  show <ID> [--full]        Show details for a single request.'
    puts '  browse <ID>               Open a browser window and review a specified request.'
    puts '  checkout <ID> [--branch]  Checkout a specified request\'s changes to your local repository.'
    puts '  approve <ID>              Add an approving comment to a specified request.'
    puts '  merge <ID>                Accept a specified request by merging it into master.'
    puts '  close <ID>                Close a specified request.'
    puts '  prepare                   Creates a new local branch for a request.'
    puts '  create                    Create a new request.'
    puts '  clean <ID> [--force]      Delete a request\'s remote and local branches.'
    puts '  clean --all               Delete all obsolete branches.'
  end


  # Check existence of specified request and assign @current_request.
  def request_exists?(state = 'open', request_id = nil)
    # NOTE: If request_id is set explicitly we might need to update to get the
    # latest changes from GitHub, as this is called from within another method.
    automated = !request_id.nil?
    update(state) if automated
    request_id ||= @args.shift.to_i
    if request_id == 0
      puts 'Please specify a valid ID.'
      return false
    end
    @current_request = @current_requests.find { |req| req['number'] == request_id }
    unless @current_request
      # Additional try to get an older request from Github by specifying the number.
      request = @github.pull_request source_repo, request_id
      @current_request = request if request.state == state
    end
    if @current_request
      true
    else
      # No output for automated checks.
      puts "Request '#{request_id}' could not be found among all '#{state}' requests." unless automated
      false
    end
  end


  # Get latest changes from GitHub.
  def update(state = 'open')
    @current_requests = @github.pull_requests(source_repo, state)
    repos = @current_requests.collect do |request|
      repo = request.head.repository
      "#{repo.owner}/#{repo.name}" if repo
    end
    repos.uniq.compact.each do |repo|
      git_call "fetch git@github.com:#{repo}.git +refs/heads/*:refs/pr/#{repo}/*"
    end
  end


  # Cleans a single request's obsolete branches.
  def clean_single(force_deletion = false)
    update('closed')
    return unless request_exists?('closed')
    # Ensure there are no unmerged commits or '--force' flag has been set.
    branch_name = @current_request['head']['ref']
    if unmerged_commits?(branch_name) and not force_deletion
      return puts "Won't delete branches that contain unmerged commits. Use '--force' to override."
    end
    delete_branch(branch_name)
  end


  # Cleans all obsolete branches.
  def clean_all
    update
    # Protect all open requests' branches from deletion.
    protected_branches = @current_requests.collect { |request| request['head']['ref'] }
    # Select all branches with the correct prefix.
    review_branches = all_branches.select { |branch| branch.include?('review_') }
    # Only use uniq branch names (no matter if local or remote).
    review_branches.collect { |branch| branch.split('/').last }.uniq.each do |branch_name|
      # Only clean up obsolete branches.
      unless protected_branches.include?(branch_name) or unmerged_commits?(branch_name, false)
        delete_branch(branch_name)
      end
    end
  end


  # Delete local and remote branches that match a given name.
  def delete_branch(branch_name)
    # Delete local branch if it exists.
    git_call("branch -D #{branch_name}", true) if branch_exists?(:local, branch_name)
    # Delete remote branch if it exists.
    git_call("push origin :#{branch_name}", true) if branch_exists?(:remote, branch_name)
  end


  # Returns a boolean stating whether there are unmerged commits on the local or remote branch.
  def unmerged_commits?(branch_name, verbose = true)
    locations = []
    locations << ['', ''] if branch_exists?(:local, branch_name)
    locations << ['origin/', 'origin/'] if branch_exists?(:remote, branch_name)
    locations = locations + [['', 'origin/'], ['origin/', '']] if locations.size == 2
    if locations.empty?
      puts 'Nothing to do. All cleaned up already.' if verbose
      return false
    end
    # Compare remote and local branch with remote and local master.
    responses = locations.collect do |location|
      git_call "cherry #{location.first}#{target_branch} #{location.last}#{branch_name}"
    end
    # Select commits (= non empty, not just an error message and not only duplicate commits staring with '-').
    unmerged_commits = responses.reject do |response|
      response.empty? or response.include?('fatal: Unknown commit') or response.split("\n").reject { |x| x.index('-') == 0 }.empty?
    end
    # If the array ain't empty, we got unmerged commits.
    if unmerged_commits.empty?
      false
    else
      puts "Unmerged commits on branch '#{branch_name}'."
      true
    end
  end


  # Returns a boolean stating whether a branch exists in a specified location.
  def branch_exists?(location, branch_name)
    return false unless [:remote, :local].include? location
    prefix = location == :remote ? 'remotes/origin/' : ''
    all_branches.include?(prefix + branch_name)
  end


  # System call to 'git'.
  def git_call(command, verbose = debug_mode, enforce_success = false)
    if verbose
      puts
      puts "  git #{command}"
      puts
    end
    output = `git #{command}`
    puts output if verbose and not output.empty?
    # If we need sth. to succeed, but it doesn't stop right there.
    if enforce_success and not last_command_successful?
      puts output unless output.empty?
      raise UnprocessableState
    end
    output
  end


  # Show current discussion for @current_request.
  def discussion
    # FIXME:
    puts 'This needs to be updated to work with API v3.'
    return
    request = @github.pull_request source_repo, @current_request['number']
    result = request['discussion'].collect do |entry|
      user = entry['user'] || entry['author']
      name = user['login'].empty? ? user['name'] : user['login']
      output = "\e[35m#{name}\e[m "
      case entry['type']
        # Comments:
        when "IssueComment", "CommitComment", "PullRequestReviewComment"
          output << "added a comment"
          output << " to \e[36m#{entry['commit_id'][0..6]}\e[m" if entry['commit_id']
          output << " on #{format_time(entry['created_at'])}"
          unless entry['created_at'] == entry['updated_at']
            output << " (updated on #{format_time(entry['updated_at'])})"
          end
          output << ":\n#{''.rjust(output.length + 1, "-")}\n"
          output << "> \e[32m#{entry['path']}:#{entry['position']}\e[m\n" if entry['path'] and entry['position']
          output << entry['body']
        # Commits:
        when "Commit"
          output << "authored commit \e[36m#{entry['id'][0..6]}\e[m on #{format_time(entry['authored_date'])}"
          unless entry['authored_date'] == entry['committed_date']
            output << " (committed on #{format_time(entry['committed_date'])})"
          end
          output << ":\n#{''.rjust(output.length + 1, "-")}\n#{entry["message"]}"
      end
      output << "\n\n\n"
    end
    puts result.compact unless result.empty?
  end


  # Display helper to make output more configurable.
  def format_text(info, size)
    info.to_s.gsub("\n", ' ')[0, size-1].ljust(size)
  end


  # Display helper to unify time output.
  def format_time(time_string)
    Time.parse(time_string).strftime('%d-%b-%y')
  end


  # Returns a string that specifies the source repo.
  def source_repo
    "#{@user}/#{@repo}"
  end


  # Returns a string that specifies the source branch.
  def source_branch
    git_call('branch').chomp!.match(/\*(.*)/)[0][2..-1]
  end


  # Returns a string consisting of source repo and branch.
  def source
    "#{source_repo}/#{source_branch}"
  end


  # Returns a string that specifies the target repo.
  def target_repo
    # TODO: Enable possibility to manually override this and set arbitrary repositories.
    source_repo
  end


  # Returns a string that specifies the target branch.
  def target_branch
    # TODO: Enable possibility to manually override this and set arbitrary branches.
    ENV['TARGET_BRANCH'] || 'master'
  end


  # Returns a string consisting of target repo and branch.
  def target
    "#{target_repo}/#{target_branch}"
  end


  # Returns an Array of all existing branches.
  def all_branches
    @branches ||= git_call('branch -a').split("\n").collect { |s| s.strip }
  end


  # Returns a boolean stating whether a specified commit has already been merged.
  def merged?(sha)
    not git_call("rev-list #{sha} ^HEAD 2>&1").split("\n").size > 0
  end


  # Uses Octokit to access GitHub.
  def configure_github_access
    if Settings.instance.oauth_token
      @github = Octokit::Client.new(
        :login       => Settings.instance.username,
        :oauth_token => Settings.instance.oauth_token
      )
      @github.login
    else
      configure_oauth
      configure_github_access
    end
  end


  def debug_mode
    Settings.instance.review_mode == 'debug'
  end


  # Collect git config information in a Hash for easy access.
  # Checks '~/.gitconfig' for credentials.
  def git_config
    unless @git_config
      # Read @git_config from local git config.
      @git_config = { }
      config_list = git_call('config --list', false)
      config_list.split("\n").each do |line|
        key, value = line.split('=')
        @git_config[key] = value
      end
    end
    @git_config
  end


  # Returns an array consisting of information on the user and the project.
  def repo_info
    # Extract user and project name from GitHub URL.
    url = git_config['remote.origin.url']
    if url.nil?
      puts "Error: Not a git repository."
      return [nil, nil]
    end
    user, project = github_user_and_project(url)
    # If there are no results yet, look for 'insteadof' substitutions in URL and try again.
    unless user && project
      short, base = github_insteadof_matching(config_hash, url)
      if short and base
        url = url.sub(short, base)
        user, project = github_user_and_project(url)
      end
    end
    [user, project]
  end


  # Looks for 'insteadof' substitutions in URL.
  def github_insteadof_matching(config_hash, url)
    first = config_hash.collect { |key, value|
      [value, /url\.(.*github\.com.*)\.insteadof/.match(key)]
    }.find { |value, match|
      url.index(value) and match != nil
    }
    first ? [first[0], first[1][1]] : [nil, nil]
  end


  # Extract user and project name from GitHub URL.
  def github_user_and_project(github_url)
    matches = /github\.com.(.*?)\/(.*)/.match(github_url)
    matches ? [matches[1], matches[2].sub(/\.git\z/, '')] : [nil, nil]
  end


  # Returns a boolean stating whether the last issued system call was successful.
  def last_command_successful?
    $?.exitstatus == 0
  end

  # Returns an array where the 1st item is the title and the 2nd one is the body
  def create_title_and_body(target_branch)
    commits = git_call("log --format='%H' HEAD...#{target_branch}").lines.count
    puts "commits: #{commits}"
    if commits == 1
      # we can create a really specific title and body
      title = git_call("log --format='%s' HEAD...#{target_branch}").chomp
      body  = git_call("log --format='%b' HEAD...#{target_branch}").chomp
    else
      title = "[Review] Request from '#{git_config['github.login']}' @ '#{source}'"
      body  = "Please review the following changes:\n"
      body += git_call("log --oneline HEAD...#{target_branch}").lines.map{|l| "  * #{l.chomp}"}.join("\n")
    end

    tmpfile = Tempfile.new('git-review')
    tmpfile.write(title + "\n\n" + body)
    tmpfile.flush
    editor = ENV['TERM_EDITOR'] || ENV['EDITOR']
    warn "Please set $EDITOR or $TERM_EDITOR in your .bash_profile." unless editor

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
