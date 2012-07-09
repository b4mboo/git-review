$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'

describe GitReview do

  before :each do
    # Silence output.
    GitReview.any_instance.stub(:puts)
    # Stub external dependency @git_config (local file).
    GitReview.any_instance.stub(:git_config).and_return(
      'github.login' => 'default_login',
      'github.password' => 'default_password',
      'remote.origin.url' => 'git@github.com:user/project.git'
    )
    # Stub external dependency @github (remote server).
    @github = mock 'GitHub'
    Octokit::Client.stub(:new).and_return(@github)
    @github.stub(:login)
  end

  describe 'without any parameters' do

    it 'should show the help page' do
      GitReview.any_instance.should_receive(:puts).with('Usage: git review <command>')
      GitReview.new
    end

  end
end
