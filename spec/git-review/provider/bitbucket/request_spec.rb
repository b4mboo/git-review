require_relative '../../../spec_helper'

describe 'Provider: Bitbucket - Request' do

  include_context 'request_context'

  subject { ::GitReview::Provider::Bitbucket.new(server) }

  let(:server) { ::GitReview::Server.any_instance }
  let(:settings) { ::GitReview::Settings.any_instance }

  before :each do
    ::GitReview::Provider::Bitbucket.any_instance.stub :git_call
    settings.stub(:bitbucket_consumer_key).and_return('CONSUMER_KEY')
    settings.stub(:bitbucket_consumer_secret).and_return('CONSUMER_SECRET')
    settings.stub(:bitbucket_token).and_return('TOKEN')
    settings.stub(:bitbucket_token_secret).and_return('TOKEN_SECRET')
    settings.stub(:bitbucket_username).and_return(user_login)
  end

  it 'allows to construct a collection of request instances from an Array' do
    test_number = 23
    test_number.should_not eq(request_number)
    test_req = bitbucket_request_hash.merge(:id => test_number)
    requests = Request.from_bitbucket(subject, [bitbucket_request_hash, test_req])
    req1 = requests.first
    req1.class.should eq(Request)
    req1.number.should eq(request_number)
    req2 = requests.last
    req2.class.should eq(Request)
    req2.number.should eq(test_number)
  end

end
