module Internals

  private

  # Setup variables and call actual commands.
  def initialize(args = [])
    @args = args
    command = args.shift
    if command && self.respond_to?(command)
      unless command == 'help'
        @user, @repo = repo_info
        return unless @user && @repo && configure_github_access
        update unless command == 'clean'
      end
      self.send command
    else
      unless command.nil? || command.empty? || %w(-h --help).include?(command)
        puts "git-review: '#{command}' is not a valid command.\n\n"
      end
      help
    end
  rescue UnprocessableState
    puts 'Execution of git-review command stopped.'
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
    @current_request = @current_requests.find { |req| req.number == request_id }
    unless @current_request
      # Additional try to get an older request from Github by specifying the id.
      request = Request.find @github, source_repo, request_id
      @current_request = request if request.state == state
    end
    if @current_request
      true
    else
      # No output for automated checks.
      unless automated
        puts "Could not find an '#{state}' request wit ID ##{request_id}."
      end
      false
    end
  end


  # Get latest changes from GitHub.
  def update(state = 'open')
    @current_requests = Request.find_all @github, source_repo, state
    repos = @current_requests.collect do |request|
      repo = request.head.repo
      "#{repo.owner.login}/#{repo.name}" if repo
    end
    repos.uniq.compact.each do |rep|
      git_call "fetch git@github.com:#{rep}.git +refs/heads/*:refs/pr/#{rep}/*"
    end
  end


  # Cleans a single request's obsolete branch.
  def clean_single(force_deletion = false)
    update 'closed'
    return unless request_exists?('closed')
    # Ensure there are no unmerged commits or '--force' flag has been set.
    branch_name = @current_request.head.ref
    if unmerged_commits?(branch_name) and not force_deletion
      puts 'Won\'t delete branches that contain unmerged commits.'
      puts 'Use \'--force\' to override.'
      return
    end
    delete_branch(branch_name)
  end


  # Cleans all obsolete branches.
  def clean_all
    update
    # Protect all open requests' branches from deletion.
    protected_branches = @current_requests.collect {|request| request.head.ref }
    # Select all branches with the correct prefix.
    review_branches = all_branches.collect do |branch|
      # Only use uniq branch names (no matter if local or remote).
      branch.split('/').last if branch.include?('review_')
    end
    (review_branches.compact.uniq - protected_branches).each do |branch_name|
      # Only clean up obsolete branches.
      delete_branch(branch_name) unless unmerged_commits?(branch_name, false)
    end
  end


  # Delete local and remote branches that match a given name.
  def delete_branch(branch_name)
    # Delete local branch if it exists.
    if branch_exists?(:local, branch_name)
      git_call("branch -D #{branch_name}", true)
    end
    # Delete remote branch if it exists.
    if branch_exists?(:remote, branch_name)
      git_call("push origin :#{branch_name}", true)
    end
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
    # If we need sth. to succeed, but it doesn't, then stop right there.
    if enforce_success and not last_command_successful?
      puts output unless output.empty?
      raise UnprocessableState
    end
    output
  end


  # Show current discussion for @current_request.
  # The structure of a discussion is like the following
  # - Some pull request
  #    - Comment 1
  #    - Comment 2
  #    - Some commit
  #      -Comment 1 on commit
  #      -Comment 2 on commit
  #    - ...
  def discussion
    commits_comments = @current_request.pull_commits.inject([]) do |cat, commit|
      cat + commit.comments
    end
    comments = (@current_request.issue_comments +
      @current_request.pull_comments +
      @current_request.pull_commits +
      commits_comments).sort!
    result = comments.collect do |entry|
      "#{entry.to_s}\n\n\n"
    end
    puts result.compact unless result.empty?


    # # FIXME:
    # puts 'This needs to be updated to work with API v3.'
    # return
    # request = @github.pull_request source_repo, @current_request['number']
    # result = request['discussion'].collect do |entry|
    #   user = entry['user'] || entry['author']
    #   name = user['login'].empty? ? user['name'] : user['login']
    #   output = "\e[35m#{name}\e[m "
    #   case entry['type']
    #     # Comments:
    #     when "IssueComment", "CommitComment", "PullRequestReviewComment"
    #       output << "added a comment"
    #       output << " to \e[36m#{entry['commit_id'][0..6]}\e[m" if entry['commit_id']
    #       output << " on #{format_time(entry['created_at'])}"
    #       unless entry['created_at'] == entry['updated_at']
    #         output << " (updated on #{format_time(entry['updated_at'])})"
    #       end
    #       output << ":\n#{''.rjust(output.length + 1, "-")}\n"
    #       output << "> \e[32m#{entry['path']}:#{entry['position']}\e[m\n" if entry['path'] and entry['position']
    #       output << entry['body']
    #     # Commits:
    #     when "Commit"
    #       output << "authored commit \e[36m#{entry['id'][0..6]}\e[m on #{format_time(entry['authored_date'])}"
    #       unless entry['authored_date'] == entry['committed_date']
    #         output << " (committed on #{format_time(entry['committed_date'])})"
    #       end
    #       output << ":\n#{''.rjust(output.length + 1, "-")}\n#{entry["message"]}"
    #   end
    #   output << "\n\n\n"
    # end
    # puts result.compact unless result.empty?
  end


  # Returns a string that specifies the source repo.
  def source_repo
    "#{@user}/#{@repo}"
  end


  # Returns a string that specifies the current source branch.
  def source_branch
    git_call('branch').chomp.match(/\*(.*)/)[0][2..-1]
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

  # Returns a boolean stating whether we are already on a feature branch.
  def on_feature_branch?
    # If current and target branch are the same, we are not on a feature branch.
    # If they are different, but we are on master, we should still to switch to
    # a separate feature branch (since master makes for a poor feature branch).
    !(source_branch == target_branch || source_branch == 'master')
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
