class Commit < Base

  nests user: User,
        repo: Repository

  attr_accessor :sha,
                :comment_count,
                :created_at,
                :message

  def to_s
    text = "\e[35m#{user.login}\e[m "
    text << "committed \e[36m#{sha[0..6]}\e[m "
    if created_at
      text << "on #{created_at.review_time}"
    end
    text << ":\n#{''.rjust(text.length + 1, "-")}\n"
    text << "#{message}"
    text << "\n\n"
  end

end
