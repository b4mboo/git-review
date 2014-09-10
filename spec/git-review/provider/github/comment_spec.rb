require_relative '../../../spec_helper'

describe 'Provider: Github - Comment' do

  include_context 'comment_context'

  subject { ::GitReview::Provider::Github.new(server) }

  let(:server) { ::GitReview::Server.any_instance }
  let(:settings) { ::GitReview::Settings.any_instance }

  before :each do
    ::GitReview::Provider::Github.any_instance.stub :git_call
    settings.stub(:oauth_token).and_return('token')
    settings.stub(:username).and_return(user_login)
  end

  it 'allows to construct a collection of comment instances from an Array' do
    test_body = 'new body'
    test_body.should_not eq(comment_body)
    test_comment = github_comment_hash.merge(:body => comment_body)
    comments = Comment.from_github(subject, [github_comment_hash, test_comment])
    comment1 = comments.first
    comment1.class.should eq(Comment)
    comment1.body.should eq(comment_body)
    comment2 = comments.last
    comment2.class.should eq(Comment)
    comment2.body.should eq(comment_body)
  end

end
