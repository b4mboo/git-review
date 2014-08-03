class Request < Base

  nests head: Commit

  attr_accessor :number,
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
    text << "\n#{title}\n\n"
    text << "#{body}\n\n" unless body.empty?
    text
  end

  # Collect the discussion details.
  def discussion
    text = "\nProgress  :\n\n"
    activities = server.request_comments(number) + server.commits(number)
    activities.sort_by(&:created_at).each { |activity|
      text << activity.to_s
    }
    text
  end

  # get the number of comments
  def comments_count
    comments + review_comments
  end

  # Construct a warning if someone deleted the source repo.
  def missing_repo_warning
    text = "Sorry, #{head.user.login} deleted the source repository.\n"
    text << "git-review doesn't support this.\n"
    text << "Tell the contributor not to do this.\n\n"
    text << "You can still manually patch your repo by running:\n\n"
    text << "  curl #{patch_url} | git am\n\n"
    text
  end

end
