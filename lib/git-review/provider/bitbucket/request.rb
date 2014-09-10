class Request

  def self.from_bitbucket(server, response)
    return response.collect { |r| from_bitbucket(server, r) } if response.is_a? Array
    self.new(
        server: server,
        number: response.id,
        title: response.title,
        body: response.description,
        state: response.state,
        updated_at: response.updated_on,
        html_url: response.links.html.href,
        patch_url: response.links.diff.href,
        comments: response.comments,
        head: {
            sha: response.source.commit[:hash],
            label: response.source.repository.name,
            ref: response.source.branch.name,
            user: {
                login: response.author.username
            },
            repo: {
                owner: response.author.username,
                name: response.source.repository.name
            }
        }
    )
  end

end
