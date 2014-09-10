shared_context 'commit_context' do

  let(:head_sha) { 'head_sha' }
  let(:head_label) { 'head_label' }
  let(:head_repo) { "#{user_login}/#{repo_name}" }
  let(:repo_name) { 'repo' }
  let(:feature_name) { 'some_name' }
  let(:head_ref) { "review_010113_#{feature_name}"}
  let(:user_login) { 'user' }
  let(:comment_count) { 23 }

  # Note: single commit and commit in pull request head has different structures
  let(:head_commit_hash) {
    # See https://developer.github.com/v3/pulls/#get-a-single-pull-request
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
        user: {
            login: user_login
        },
        commit: {
            commnt_count: comment_count
        }
    )
  }

  let(:github_commit_hash) {
    # See https://developer.github.com/v3/pulls/#list-commits-on-a-pull-request
    Hashie::Mash.new(
        sha: head_sha,
        commit: {
            author: {
                name: 'author_name',
                date: '2011-04-14T16:00:49Z'
            },
            committer: {
                name: 'committer name',
                date: '2011-04-14T16:00:49Z'
            },
            message: 'some message',
            comment_count: comment_count
        },
        author: {
            login: user_login
        },
        committer: {
            login: user_login
        }
    )
  }

  let(:bitbucket_commit_hash) {
    Hashie::Mash.new(
        hash: head_sha,
        message: 'some message',
        date: '2011-04-14T16:00:49Z',
        author: {
            user: {
                username: user_login
            }
        }
    )
  }

  let(:commit) { Commit.from_github(::GitReview::Server.new, head_commit_hash) }

end
