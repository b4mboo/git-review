# GitHub specific constructor for git-review's Commit model.
class Commit

  # Create a new Commit instance from a GitHub-structured attributes hash.
  # NOTE: Allows to provide an Array of GH-Hashes,
  #       in which case it will also return an Array of Commits.
  def self.from_github(server, response)
    # Use recursion to handle Arrays of responses.
    return response.collect{|r| from_github(server, r)} if response.is_a? Array
    # FIXME: Get info from GitHub's API and adjust structure.
    self.new(
      sha: response.sha,
      ref: response.ref,
      label: response.label,
      message: response.message,
      user: {
        login: response.user.login
      },
      repo: {
        # NOTE: This can become nil, if the repo has been deleted ever since.
        owner: (response.repo ? response.repo.owner : nil),
        name: (response.repo ? response.repo.name : nil)
      }
    )
  end

end
