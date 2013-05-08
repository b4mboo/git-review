class Comment

  include Formattable
  include Accessible
  extend Nestable

  nests :user => User

  attr_accessor :id,
                :body,
                :commit_id,
                :updated_at,
                :created_at

  def <=>(other)
    if other.class == Commit
      updated_at <=> other.commit.committer.date
    else
      updated_at <=> other.updated_at
    end
  end

  def to_s
    output = ""
    name = user.login
    output << "\e[35m#{name}\e[m "
    output << "added a comment"
    output << " to \e[36m#{id}\e[m"
    output << " on #{format_time(created_at)}"
    unless created_at == updated_at
      output << " (updated on #{format_time(updated_at)})"
    end
    output << ":\n#{''.rjust(output.length + 1, "-")}\n"
    output << body
    output
  end

end
