# GitHub specific constructor for git-review's Request model.
class Request

  # Create a new request instance from a GitHub-structured attributes hash.
  # NOTE: Allows to provide an Array of GH-Hashes,
  #       in which case it will also return an Array of Requests.
  def self.from_github(server, response)
    # Use recursion to handle Arrays of responses.
    return response.collect{|r| from_github(server, r)} if response.is_a? Array
    self.new(
      server: server,
      number: response.number,
      title: response.title,
      body: response.body,
      state: response.state,
      html_url: response._links.html.href,
      # FIXME: Where do we get the patch URL from?
      patch_url: nil,
      updated_at: response.updated_at,
      comments: response.comments,
      review_comments: response.review_comments,
      head: {
        sha: response.head.sha,
        ref: response.head.ref,
        label: response.head.label,
        user: {
          login: response.head.user.login
        },
        repo: {
          # NOTE: This can become nil, if the repo has been deleted ever since.
          owner: (response.head.repo ? response.head.repo.owner.login : nil),
          name: (response.head.repo ? response.head.repo.name : nil)
        }
      }
    )
  end

end
