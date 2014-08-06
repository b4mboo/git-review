# GitHub specific constructor for git-review's Comment model.
class Comment

  # Create a new Comment instance from a GitHub-structured attributes hash.
  # NOTE: Allows to provide an Array of GH-Hashes,
  #       in which case it will also return an Array of Comments.
  def self.from_github(server, response)
    # Use recursion to handle Arrays of responses.
    return response.collect{|r| from_github(server, r)} if response.is_a? Array
    self.new(
      server: server,
      body: response.body,
      updated_at: response.updated_at,
      created_at: response.created_at,
      user: {
        login: response.user.login
      },
      commit_id: response.commit_id
    )
  end

end
