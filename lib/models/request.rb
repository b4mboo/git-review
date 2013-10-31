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
    line << server.comments_count(self).to_s.review_ljust(10)
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
    text = "Progress  :\n\n"
    text << "#{server.discussion(number)}\n"
    text
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
