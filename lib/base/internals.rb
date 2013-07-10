module Internals

  private

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
      raise Errors::UnprocessableState
    end
    output
  end

  # @return [Boolean] whether the last issued system call was successful
  def last_command_successful?
    $?.exitstatus == 0
  end

  def debug_mode
    ::GitReview::Settings.instance.review_mode == 'debug'
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
    issue_comments = @github.issue_comments(source_repo, @current_request['number'])
    pull_commits = @github.pull_commits(source_repo, @current_request['number'])
    # A bit hacky here. Just put everything in chronological order.
    # Issue comments and pull commits have different structures.
    comments = (issue_comments + pull_commits).sort! { |x,y|
      (x.created_at || x.commit.committer.date) <=> (y.created_at || y.commit.committer.date)
    }
    result = comments.collect do |entry|
      output = ""
      if entry.commit?
        # it is a pull commit
        name = entry.committer.login
        output << "\e[35m#{name}\e[m "
        output << "committed \e[36m#{entry['sha'][0..6]}\e[m on #{format_time(entry.commit.committer.date)}"
        output << ":\n#{''.rjust(output.length + 1, "-")}\n#{entry.commit.message}"
        # FIXME:
        # Comments on commits does not work yet, as the commits may come from forks
        # haven't found a reliable way to identify the forked repo.
        # commit_comments = @github.commit_comments(source_repo, entry.sha)
        # commit_comments.each do |cc|
        # end
      else
        # it is a issue comment
        name = entry.user.login
        output << "\e[35m#{name}\e[m "
        output << "added a comment"
        output << " to \e[36m#{entry.id}\e[m"
        output << " on #{format_time(entry.created_at)}"
        unless entry['created_at'] == entry['updated_at']
          output << " (updated on #{format_time(entry.updated_at)})"
        end
        output << ":\n#{''.rjust(output.length + 1, "-")}\n"
        output << entry.body
      end
      output << "\n\n\n"
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


  # Display helper to make output more configurable.
  def format_text(info, size)
    info.to_s.gsub("\n", ' ')[0, size-1].ljust(size)
  end


  # Display helper to unify time output.
  def format_time(time_string)
    Time.parse(time_string).strftime('%d-%b-%y')
  end


  # Returns a string that specifies the target repo.
  def target_repo
    # TODO: Enable possibility to manually override this and set arbitrary repositories.
    source_repo
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


  # Returns an array where the 1st item is the title and the 2nd one is the body
  def create_title_and_body(target_branch)
    git_config = ::GitReview::Local.instance.config
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
