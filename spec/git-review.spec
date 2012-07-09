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

    it 'shows the help page' do
      GitReview.any_instance.should_receive(:puts).with('Usage: git review <command>')
      GitReview.new
    end

  end


  describe "'list'" do

    it 'shows all open pull requests'

  end


  describe "'show'" do

    it 'requires an ID as additional parameter'

    it 'shows a single pull request'

    it 'shows a pull request\'s full diff if the optional parameter --full is appended'

  end


  describe "'browse'" do

    it 'requires an ID as additional parameter'

    it 'opens the pull request\'s page on GitHub in a browser'

  end


  describe "'checkout'" do

    it 'requires an ID as additional parameter'

    it 'creates a headless state in the local git repo that holds the request\'s code'

    it 'creates a local branch with the pull request\'s code if the optional parameter --branch is appended'

  end


  describe "'approve'" do

    it 'requires an ID as additional parameter'

    it 'posts an approving comment in your name to the request\'s page'

  end


  describe "'merge'" do

    it 'requires an ID as additional parameter'

    it 'merges the request with your current branch'

  end


  describe "'close'" do

    it 'requires an ID as additional parameter'

    it 'closes the request'

  end


  describe "'prepare'" do

    it 'creates a local branch with review prefix'

    it 'lets the user choose a name for the branch'

    it 'moves uncommitted changes to the new branch'

    it 'moves unpushed commits to the new branch'

  end


  describe "'create'" do

    it 'calls \'prepare\' unless it is called from a branch other than master'

    it 'pushes the commits to a remote branch'

    it 'creates a pull request from that feature branch to master'

    it 'lets the user return to the branch she was working on before the call'

  end


  describe "'clean'" do

    it 'requires either an ID or the additional parameter --all'

    it 'removes obsolete remote branches with review prefix'

    it 'removes obsolete local branches with review prefix'

    it 'takes the optional parameter --force to override protection of unmerged changes'

  end

end
