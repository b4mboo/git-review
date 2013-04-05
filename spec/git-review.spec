require 'spec_helper'

describe GitReview do

  subject { GitReview.new }
  let(:github) { mock :github }
  let(:request) { mock :request }
  let(:head_sha) { 'head_sha' }
  let(:title) { 'some title' }
  let(:mock_id) { 42 }
  let(:mock_sha) { 'fake' }
  let(:mock_request) {
    {
      'number' => mock_id,
      'state'=> 'open',
      'title' => title,
      'updated_at' => Time.now.to_s,
      'head' => {
        'sha' => mock_sha
      }
    }
  }

  before :each do
    # Silence output.
    GitReview.any_instance.stub(:puts)

    ## Stub external dependency .git/config (local file).
    #subject.stub(:git_call).
    #  with('config --list', false).and_return(
    #  'github.login=default_login\n' +
    #  'github.password=default_password\n' +
    #  'remote.origin.url=git@github.com:user/project.git'
    #)
    # Stub external dependency @github (remote server).
    subject.instance_variable_set(:@github, github)
    #Octokit::Client.stub(:new).and_return(github)
    #github.stub(:login)
  end


  describe 'without any parameters' do

    it 'shows the help page' do
      GitReview.any_instance.should_receive(:puts).with(
        'Usage: git review <command>'
      )
      GitReview.new
    end

  end


  describe "'list'" do

    it 'shows all open pull requests' do
      assume :@current_requests, [request, request]
      github.should_receive(:pull_request).twice.and_return(request)
      request.stub_chain(:head, :sha).and_return(head_sha)
      subject.should_receive(:merged?).with(head_sha).twice.and_return(false)
      request.should_receive(:number).exactly(4).times.and_return(1, 1, 2, 2)
      request.should_receive(:updated_at).twice.and_return(Time.now.to_s)
      request.should_receive(:comments).twice.times.and_return(23)
      request.should_receive(:review_comments).twice.times.and_return(23)
      request.should_receive(:title).twice.and_return('first', 'second')
      subject.should_receive(:puts).with(include 'Pending requests')
      subject.should_not_receive(:puts).with(include 'No pending requests')
      subject.should_receive(:puts).with(include 'first').ordered
      subject.should_receive(:puts).with(include 'second').ordered
      subject.list
    end

    it 'allows for an optional argument --reverse to sort the output' do
      assume :@args, ['--reverse']
      assume :@current_requests, [request, request]
      github.should_receive(:pull_request).twice.and_return(request)
      request.stub_chain(:head, :sha).and_return(head_sha)
      subject.should_receive(:merged?).with(head_sha).twice.and_return(false)
      request.should_receive(:number).exactly(4).times.and_return(1, 1, 2, 2)
      request.should_receive(:updated_at).twice.and_return(Time.now.to_s)
      request.should_receive(:comments).twice.and_return(23)
      request.should_receive(:review_comments).twice.times.and_return(23)
      request.should_receive(:title).twice.and_return('first', 'second')
      subject.should_receive(:puts).with(include 'Pending requests')
      subject.should_not_receive(:puts).with(include 'No pending requests')
      subject.should_receive(:puts).with(include 'second').ordered
      subject.should_receive(:puts).with(include 'first').ordered
      subject.list
    end

    it 'respects local changes when determining whether requests are merged' do
      assume :@current_requests, [request]
      request.should_receive(:number).and_return(1)
      github.should_receive(:pull_request).and_return(request)
      request.stub_chain(:head, :sha).and_return(head_sha)
      subject.should_receive(:merged?).with(head_sha).and_return(true)
      subject.should_receive(:puts).with(include 'No pending requests')
      subject.should_not_receive(:puts).with(include 'Pending requests')
      subject.list
    end

    it 'knows when there are no open pull requests' do
      assume :@current_requests, []
      subject.instance_variable_get(:@current_requests).should be_empty
      subject.should_receive(:puts).with(include 'No pending requests')
      subject.should_not_receive(:puts).with(include 'Pending requests')
      subject.list
    end

  end

  describe "'show'" do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.show
    end

    it 'shows a single pull request' do
      assume :@args, [mock_id]
      assume :@current_requests, [mock_request]
      # assert the title gets printed.
      subject.should_receive(:puts).with(title)
      subject.show
    end

    it 'shows a pull request\'s full diff if the optional parameter --full is appended'

  end


  describe "'browse'" do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.browse
    end

    it 'opens the pull request\'s page on GitHub in a browser'

  end


  describe "'checkout'" do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.checkout
    end

    it 'creates a headless state in the local git repo that holds the request\'s code'

    it 'creates a local branch with the pull request\'s code if the optional parameter --branch is appended'

  end


  describe "'approve'" do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.approve
    end

    it 'posts an approving comment in your name to the request\'s page'

  end


  describe "'merge'" do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.merge
    end

    it 'merges the request with your current branch'

  end


  describe "'close'" do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.close
    end

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

    before :each do
      subject.stub(:git_call).with('remote prune origin')
    end

    it 'requires either an ID or the additional parameter --all' do
      subject.should_receive(:puts).with(include('either an ID or the option "--all"'))
      subject.clean
    end

    it 'removes obsolete remote branches with review prefix'

    it 'removes obsolete local branches with review prefix'

    it 'takes the optional parameter --force to override protection of unmerged changes'

  end

end
