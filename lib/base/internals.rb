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
      raise ::GitReview::Errors::UnprocessableState
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

end
