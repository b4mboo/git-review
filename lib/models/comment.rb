class Comment < Base

  nests user: User

  attr_accessor :body,
                :updated_at,
                :created_at

  def to_s
    text = "\e[35m#{user.login}\e[m "
    text << "added a comment "
    if commit_id
      text << "to commit \e[36m#{commit_id[0..6]}\e[m "
    end
    text << "on #{created_at.review_time} "
    unless created_at == updated_at
      text << "(updated on #{updated_at.review_time})"
    end
    text << ":\n#{''.rjust(text.length + 1, "-")}\n"
    text << "#{body}"
    text << "\n\n"
  end

end
