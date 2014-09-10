class Commit

  def self.from_bitbucket(server, response)
    return response.collect { |r| from_bitbucket(server, r) } if response.is_a? Array
    self.new(
        server: server,
        sha: response[:hash],  # avoid conflicts with Ruby's #hash
        message: response.message,
        user: {
            login: response.author.user.username
        },
        created_at: response.date
    )
  end

end
