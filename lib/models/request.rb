class Request

  include Accessible
  extend Nestable

  nests head: Commit

  attr_accessor :server,
                :number,
                :title,
                :body,
                :state,
                :html_url,
                :patch_url,
                :updated_at,
                :comments,
                :review_comments


  # Build a request's summary.
  def summary
    line = number.to_s.review_ljust(8)
    line << updated_at.review_time.review_ljust(11)
    line << title.review_ljust(91)
    line
  end

  # Collect all details in a String.
  def details
    text = "ID        : #{number}\n"
    text << "Label     : #{head.label}\n"
    text << "Updated   : #{updated_at.review_time}\n"
    text << "Comments  : #{server.comments_count(self)}\n"
    text << "\n#{title}\n\n"
    text << "#{body}\n\n" unless body.empty?
    text
  end

  # Collect the discussion details.
  def discussion
    content = (commit_discussion + server.issue_discussion(self)).join
    text = "Progress  :\n\n"
    text << "#{content}\n"
    text
  end

  def commit_discussion
    discussion = ["Commits on pull request:\n\n"]
    discussion += server.commits(number).collect { |commit|
      # TODO: Move into commit model.
      # commit message
      name = commit.committer.login
      output = "\e[35m#{name}\e[m "
      output << "committed \e[36m#{commit.sha[0..6]}\e[m "
      output << "on #{commit.commit.committer.date.review_time}"
      output << ":\n#{''.rjust(output.length + 1, "-")}\n"
      output << "#{commit.commit.message}"
      output << "\n\n"
      result = [output]

      # comments on commit
      # FIXME: Wrap commit_comments into a separate method, such that
      # commit_discussion can be moved out of the GH-specific area.
      # FIXME: Fall back to the request's repo, instead of source_repo.
      comments = client.commit_comments(source_repo, commit.sha)
      result + comments.collect { |comment|
        name = comment.user.login
        output = "\e[35m#{name}\e[m "
        output << "added a comment to \e[36m#{commit.sha[0..6]}\e[m"
        output << " on #{comment.created_at.review_time}"
        unless comment.created_at == comment.updated_at
          output << " (updated on #{comment.updated_at.review_time})"
        end
        output << ":\n#{''.rjust(output.length + 1, "-")}\n"
        output << comment.body
        output << "\n\n"
      }
    }
    discussion.compact.flatten unless discussion.empty?
  end

  # Construct a warning if someone deleted the source repo.
  def missing_repo_warning
    text = "Sorry, #{self.head.user.login} deleted the source repository.\n"
    text << "git-review doesn't support this.\n"
    text << "Tell the contributor not to do this.\n\n"
    text << "You can still manually patch your repo by running:\n\n"
    text << "  curl #{self.patch_url} | git am\n\n"
    text
  end

end
