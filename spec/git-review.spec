require 'spec_helper'

describe GitReview do

  subject { GitReview.new }

  let(:github) { mock :github }
  let(:source_repo) { '/' }
  let(:head_sha) { 'head_sha' }
  let(:title) { 'some title' }
  let(:label) { 'some label' }
  let(:request_id) { 42 }

  let(:request) {
    request = Request.new(
      :number => request_id,
      :state => 'open',
      :title => title,
      :updated_at => Time.now.to_s,
      :sha => head_sha,
      :label => label,
      :comments => 0,
      :review_comments => 0
    )
    assume_on_github request
    request
  }


  before :each do
    # Silence any output during test runs.
    GitReview.any_instance.stub(:puts)
    # Stub external dependency @github (= remote server).
    subject.instance_variable_set(:@github, github)

    ## Stub external dependency .git/config (local file).
    #subject.stub(:git_call).
    #  with('config --list', false).and_return(
    #  'github.login=default_login\n' +
    #  'github.password=default_password\n' +
    #  'remote.origin.url=git@github.com:user/project.git'
    #)
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
      assume_merged false
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
      assume_merged false
      request.should_receive(:title).twice.and_return('first', 'second')
      subject.should_receive(:puts).with(include 'Pending requests')
      subject.should_not_receive(:puts).with(include 'No pending requests')
      subject.should_receive(:puts).with(include 'second').ordered
      subject.should_receive(:puts).with(include 'first').ordered
      subject.list
    end

    it 'respects local changes when determining whether requests are merged' do
      assume :@current_requests, [request]
      assume_merged true
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
      assume :@args, [request_id]
      assume :@current_requests, [request]
      subject.should_receive(:puts).with(title)
      # Ensure the request's stats are shown.
      subject.should_receive(:git_call).with(
        "diff --color=always --stat HEAD...#{head_sha}"
      )
      subject.show
    end

    it 'shows a pull request\'s diff if a parameter \'--full\' is appended' do
      assume :@args, [request_id, '--full']
      assume :@current_requests, [request]
      subject.should_receive(:puts).with(title)
      # Ensure the request's full diff is shown.
      subject.should_receive(:git_call).with(
        "diff --color=always HEAD...#{head_sha}"
      )
      subject.show
    end

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
