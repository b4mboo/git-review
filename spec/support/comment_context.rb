shared_context 'comment_context' do

  let(:comment_body) { "lorem ipsum"}
  let(:user_login) { 'user' }
  let(:request_number) { 42 }
  let(:head_sha) { 'head_sha' }

  let(:github_comment_hash) {
    Hashie::Mash.new(
      body: comment_body,
      updated_at: {
        review_time: (Time.now - 2*60)
      },
      created_at: {
        review_time: (Time.now - 5*60)
      },
      user: {
        login: user_login
      },
      id: request_number,
      # FIXME: Check GitHub's API whether there is a way to get this value.
      commit: head_sha
    )
  }

  let(:bitbucket_comment_hash) {
    Hashie::Mash.new(
      content: {
          raw: comment_body
      },
      updated_on: (Time.now - 2*60),
      created_on: (Time.now - 5*60),
      user: {
          username: user_login
      }
    )
  }

  let(:comment) { Comment.from_github(::GitReview::Server.new, github_comment_hash) }

end
