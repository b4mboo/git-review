require_relative '../../spec_helper'

describe ::GitReview::Provider::Gitlab do

  include_context 'request_context'

  subject { ::GitReview::Provider::Gitlab.new(server) }

  let(:provider) { ::GitReview::Provider::Gitlab.any_instance }
  let(:server) { ::GitReview::Server.any_instance }
  let(:settings) { ::GitReview::Settings.any_instance }
  let(:local) { ::GitReview::Local.any_instance }
  let(:client) { ::Gitlab::Client.any_instance }
  let(:token) { 'test_token' }

  before :each do
    provider.stub(:git_call)
    local.stub(:git_call).and_return('.')
    local.stub(:config).and_return({'remote.origin.url' => 'git@gitlab.com:path/repo.git'})

    # Dont save files
    settings.stub(:save!)

    # Stub STDIN
    STDIN.stub(:gets).and_return(token)
    # Stub YAML for settings
    YAML.stub(:load_file).and_return({})
  end

  context 'Authentication without token' do

    it 'asks for token' do
      expect(STDIN).to receive(:gets)
      expect(GitReview::Settings.instance).to receive(:save!)
      subject.configure_access
    end

  end

  context 'Authentication with already configured token' do

    before :each do
      YAML.stub(:load_file).and_return({'gitlab_gitlab.com_token' => token})
    end

    it 'uses a private token for authentication' do
      expect(subject).to_not receive(:configure_token)
      expect(GitReview::Settings.instance).to_not receive(:save!)
      subject.configure_access
    end

    it 'uses Gitlab gem to login to Gitlab' do
      client = double('client')
      expect(::Gitlab::Client).to receive(:new).and_return(client).at_least(:once)
      subject.configure_access
    end

#    context 'Project ID cached' do
#
#      before :each do
#        YAML.stub(:load_file).and_return(
#          'gitlab_gitlab.com_token' => token,
#          'gitlab_project_gitlab.com_repo_path' => 1
#        )
#      end
#
#      it 'gets project_id from settings' do
#        client.stub(:merge_request).with(1).and_return([])
#        expect(GitReview::Settings.instance).to_not receive(:save!)
#        subject.current_requests
#      end
#    end
#
#    context 'Project ID not cached' do
#
#      it 'gets project_id from client' do
#        client.stub(:projects).and_return([
#          ::Gitlab::ObjectifiedHash.new(
#            :path_with_namespace => 'repo/path',
#            :id => 1
#          )
#        ])
#        client.stub(:merge_request).with(1).and_return([])
#        expect(GitReview::Settings.instance).to receive(:save!)
#        subject.current_requests
#      end
#    end
#
  end
end
