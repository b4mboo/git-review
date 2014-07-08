require_relative '../../../spec_helper'

describe 'Provider: Github - Commit' do

  include_context 'commit_context'

  subject { ::GitReview::Provider::Github.new(server) }

  let(:server) { ::GitReview::Server.any_instance }
  let(:settings) { ::GitReview::Settings.any_instance }

  before :each do
    ::GitReview::Provider::Github.any_instance.stub :git_call
    settings.stub(:oauth_token).and_return('token')
    settings.stub(:username).and_return(user_login)
  end

  it 'allows to construct a collection of commit instances from an Array' do
    test_sha = 'new_sha'
    test_sha.should_not eq(head_sha)
    test_commit = commit_hash.merge(:sha => test_sha)
    commits = Commit.from_github(subject, [commit_hash, test_commit])
    commit1 = commits.first
    commit1.class.should eq(Commit)
    commit1.sha.should eq(head_sha)
    commit2 = commits.last
    commit2.class.should eq(Commit)
    commit2.sha.should eq(test_sha)
  end

end
