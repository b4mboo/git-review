shared_context 'commit_context' do

  let(:head_sha) { 'head_sha' }
  let(:head_label) { 'head_label' }
  let(:head_repo) { "#{user_login}/#{repo_name}" }
  let(:repo_name) { 'repo' }
  let(:feature_name) { 'some_name' }
  let(:head_ref) { "review_010113_#{feature_name}"}
  let(:user_login) { 'user' }

  let(:commit_hash) {
    Hashie::Mash.new(
      sha: head_sha,
      ref: head_ref,
      label: head_label,
      repo: {
        name: repo_name,
        full_name: head_repo,
        owner: {
          login: user_login
        }
      },
      user: { login: user_login }
    )
  }

  let(:commit) { Commit.from_github(::GitReview::Server.new, commit_hash) }

end
