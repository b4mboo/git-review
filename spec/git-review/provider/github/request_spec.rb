require_relative '../../../spec_helper'

describe 'Provider: Github - Request' do

  include_context 'request_context'

  subject { ::GitReview::Provider::Github.new(server) }

  let(:server) { ::GitReview::Server.any_instance }
  let(:settings) { ::GitReview::Settings.any_instance }

  before :each do
    ::GitReview::Provider::Github.any_instance.stub :git_call
    settings.stub(:oauth_token).and_return('token')
    settings.stub(:username).and_return(user_login)
  end

  it 'allows to construct a collection of request instances from an Array' do
    test_number = 23
    test_number.should_not eq(request_number)
    test_req = request_hash.merge(:number => test_number)
    requests = Request.from_github(subject, [request_hash, test_req])
    req1 = requests.first
    req1.class.should eq(Request)
    req1.number.should eq(request_number)
    req2 = requests.last
    req2.class.should eq(Request)
    req2.number.should eq(test_number)
  end

end
