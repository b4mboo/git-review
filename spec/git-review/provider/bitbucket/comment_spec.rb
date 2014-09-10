require_relative '../../../spec_helper'

describe 'Provider: Bitbucket - Comment' do

  include_context 'comment_context'

  subject { ::GitReview::Provider::Bitbucket.new(server) }

  let(:server) { ::GitReview::Server.any_instance }
  let(:settings) { ::GitReview::Settings.any_instance }

  before :each do
    ::GitReview::Provider::Bitbucket.any_instance.stub :git_call
    settings.stub(:bitbucket_username).and_return(user_login)
    settings.stub(:bitbucket_consumer_key).and_return('CONSUMER_KEY')
    settings.stub(:bitbucket_consumer_secret).and_return('CONSUMER_SECRET')
    settings.stub(:bitbucket_token).and_return('TOKEN')
    settings.stub(:bitbucket_token_secret).and_return('TOKEN_SECRET')
  end

  it 'allows to construct a collection of comment instances from an Array' do
    test_body = 'new body'
    test_body.should_not eq(comment_body)
    test_comment = bitbucket_comment_hash.merge({content: {raw: test_body}})
    comments = Comment.from_bitbucket(subject, [bitbucket_comment_hash, test_comment])
    comment1 = comments.first
    comment1.class.should eq(Comment)
    comment1.body.should eq(comment_body)
    comment2 = comments.last
    comment2.class.should eq(Comment)
    comment2.body.should eq(test_body)
  end

end
