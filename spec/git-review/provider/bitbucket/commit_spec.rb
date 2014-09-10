require_relative '../../../spec_helper'

describe 'Provider: Bitbucket - Commit' do

  include_context 'commit_context'

  subject { ::GitReview::Provider::Bitbucket.new(server) }

  let(:server) { ::GitReview::Server.any_instance }
  let(:settings) { ::GitReview::Settings.any_instance }

  before(:each) do
    ::GitReview::Provider::Bitbucket.any_instance.stub :git_call
    settings.stub(:bitbucket_username).and_return(user_login)
    settings.stub(:bitbucket_consumer_key).and_return('CONSUMER_KEY')
    settings.stub(:bitbucket_consumer_secret).and_return('CONSUMER_SECRET')
    settings.stub(:bitbucket_token).and_return('TOKEN')
    settings.stub(:bitbucket_token_secret).and_return('TOKEN_SECRET')
  end

  it 'allows to construct a collection to commit instances from an Array' do
    test_sha = 'new_sha'
    test_sha.should_not eq(head_sha)
    test_commit = bitbucket_commit_hash.merge(hash: test_sha)
    commits = Commit.from_bitbucket(subject, [bitbucket_commit_hash, test_commit])
    commit1 = commits.first
    commit1.class.should == Commit
    commit1.sha.should == head_sha
    commit2 = commits.last
    commit2.class.should == Commit
    commit2.sha.should == test_sha
  end

end
