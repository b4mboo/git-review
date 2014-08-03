class Comment

  def self.from_bitbucket(server, response)
    # Use recursion to handle Arrays of responses.
    return response.collect{ |r| from_bitbucket(server, r) } if response.is_a? Array
    self.new(
      server: server,
      body: response.content.raw,
      updated_at: response.updated_on,
      created_at: response.created_on,
      user: {
        login: response.user.username
      }
    )
  end

end
