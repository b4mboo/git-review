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


  # Build a request's summary ready to output.
  def summary
    line = number.to_s.review_ljust(8)
    line << updated_at.review_time.review_ljust(11)
    line << server.comments_count(self).to_s.review_ljust(10)
    line << title.review_ljust(91)
    line
  end

  # Collect all details in a String (ready to output).
  def details
    text = "ID        : #{number}\n"
    text << "Label     : #{head.label}\n"
    text << "Updated   : #{updated_at.review_time}\n"
    text << "Comments  : #{server.comments_count(self)}\n"
    text << "\n#{title}\n\n"
    text << "#{body}\n\n" unless body.empty?
    text
  end

end
