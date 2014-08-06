# GitHub specific constructor for git-review's Commit model.
class Commit

  # Create a new Commit instance from a GitHub-structured attributes hash.
  # NOTE: Allows to provide an Array of GH-Hashes,
  #       in which case it will also return an Array of Commits.
  def self.from_github(server, response)
    # Use recursion to handle Arrays of responses.
    return response.collect{|r| from_github(server, r)} if response.is_a? Array
    self.new(
      server: server,
      sha: response.sha,
      message: response.commit.message,
      comment_count: response.commit.comment_count,
      user: {
        login: response.author.login
      },
      created_at: response.commit.committer.date
    )
  end

end
