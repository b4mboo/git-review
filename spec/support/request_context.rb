shared_context 'request_context' do

  let(:source_repo) { '/' }
  let(:request_number) { 42 }
  let(:invalid_number) { 0 }
  let(:html_url) { 'some/path/to/github' }
  let(:head_sha) { 'head_sha' }
  let(:head_label) { 'head_label' }
  let(:head_repo) { "#{user_login}/#{repo_name}" }
  let(:repo_name) { 'repo' }
  let(:title) { 'some title' }
  let(:body) { 'some body' }
  let(:feature_name) { 'some_name' }
  let(:head_ref) { "review_010113_#{feature_name}"}
  let(:custom_target_name) { 'custom_target_name' }
  let(:branch_name) { head_ref }
  let(:user_login) { 'user' }
  let(:remote) { "review_#{user_login}" }
  let(:remote_url) { "git@provider.tld/#{user_login}/#{repo_name}" }
  let(:target_branch) { 'master' }
  let(:state) { 'open' }

  let(:github_request_hash) {
    Hashie::Mash.new(
      html_url: html_url,
      number: request_number,
      state: state,
      title: title,
      body: body,
      updated_at: Time.now.to_s,
      head: {
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
      },
      comments: 0,
      review_comments: 0,
      _links: {
        html: {
          href: html_url
        }
      }
    )
  }

  let(:bitbucket_request_hash) {
    Hashie::Mash.new(
        id: request_number,
        state: state,
        title: title,
        description: body,
        updated_on: Time.now.to_s,
        links: {
            html: {
                href: html_url
            },
            diff: {
                href: 'patch url'
            }
        },
        comments: 0,
        source: {
            commit: {
                hash: head_sha
            },
            repository: {
                name: head_label
            },
            branch: {
                name: head_ref
            }
        },
        author: {
            username: user_login
        }
    )
  }

  let(:request) { Request.from_github(::GitReview::Server.new, github_request_hash) }

end
