class Commit

  include Formattable
  include Accessible
  extend Nestable

  nests :user => User,
        :repo => Repository

  attr_accessor :sha,
                :ref,
                :label,
                :repo,
                :commit,
                :committer,
                :host, # to retrieve new data
                :head_repo # needed to get its comments


  def comments
    if @comments.nil?
      @comments = host.commit_comments(@head_repo.full_name, @sha).map do |comment|
        Comment.new comment
      end
    end
    @comments
  end

  def <=>(other)
    if other.class == Comment
      commit.committer.date <=> other.updated_at
    else
      commit.committer.date <=> other.commit.committer.date
    end
  end

  def to_s
    output = ""
    name = committer.login
    output << "\e[35m#{name}\e[m "
    output << "committed \e[36m#{sha[0..6]}\e[m on #{format_time(commit.committer.date)}"
    output << ":\n#{''.rjust(output.length + 1, "-")}\n#{commit.message}"
    output
  end

end
