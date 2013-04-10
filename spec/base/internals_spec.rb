require 'spec_helper'

describe GitReview do

  subject { GitReview.new }

  let(:user) { 'user' }
  let(:repo) { 'repo' }
  let(:command) { 'command' }


  describe 'initially' do

    before :all do
      # Allow to re-initialize an instance to be able to mock/stub it in tests.
      GitReview.define_method :init do
        initialize @args
      end
    end

    it 'shows the help page if no parameters are given' do
      subject.should_receive(:puts).with(include 'Usage: git review <command>')
      subject.init
    end

    it 'tells the user if the given command is invalid' do
      assume_valid_command false
      subject.should_receive(:puts).with(include 'not a valid command.')
      subject.init
    end

    it 'collects repository info if a valid command is given' do
      assume_valid_command
      subject.should_receive(:repo_info)
      subject.init
    end

    it 'configures the GitHub access if repo info is found' do
      assume_valid_command
      assume_repo_info_set
      subject.should_receive(:configure_github_access)
      subject.init
    end

    it 'gets the updates from GitHub before executing a command' do
      assume_valid_command
      assume_repo_info_set
      assume_github_access_configured
      subject.should_receive(:update).ordered
      subject.should_receive(command).ordered
      subject.init
    end

    it 'exits with a warning when an error occurred' do
      assume_error_raised
      subject.should_receive(:puts).with(include 'git-review command stopped')
      subject.init
    end

  end


  describe 'when' do

    include_context :request
    include_context :private


    describe 'checking requests' do

      it 'knows that 0 is not a valid request ID' do
        request.number = 0
        subject.should_receive(:puts).with('Please specify a valid ID.')
        subject.request_exists?.should be_false
      end

      it 'determines validity for a given ID' do
        assume_valid_request_id
        subject.request_exists?.should be_true
      end

      it 'looks through older requests, if it can\'t be found on the first try' do
        assume_arguments request_id
        assume_no_requests
        github.should_receive(:pull_request).
          with(source_repo, request_id).and_return(request)
        subject.request_exists?.should be_true
      end

      it 'tells the user if no request can be found' do
        assume_arguments request_id
        assume_no_requests
        assume_request_on_github false
        subject.should_receive(:puts).with(include 'Could not find')
        subject.request_exists?.should be_false
      end

      it 'quietly looks for updates on automated lookups for specified IDs' do
        assume_no_requests
        assume_request_on_github false
        subject.should_receive :update
        subject.should_not_receive(:puts).with(include 'Could not find')
        subject.request_exists?('open', request_id).should be_false
      end

    end


    describe 'updating' do

      it 'queries GitHub for a list of open requests' do
        github.should_receive(:pull_requests).
          with(source_repo, 'open').and_return([])
        subject.update
      end

      it 'allows to set a state other than the default' do
        state = 'other'
        github.should_receive(:pull_requests).
          with(source_repo, state).and_return([])
        subject.update state
      end

      it 'fetches information about the remote branches' do
        assume_requests_on_github
        request.head.repository.update_attributes(
          :owner => user,
          :name => repo
        )
        subject.should_receive(:git_call).with(
          include "fetch git@github.com:#{user}/#{repo}.git"
        )
        subject.update
      end

    end


    describe 'cleaning a single branch'


    describe 'cleaning all branches'


    describe 'deleting a branch'


    describe 'determining unmerged commits'


    describe 'determining a branch\'s existence'


    describe 'executing a git command'


    describe 'displaying a request\'s discussion'


    describe 'configuring access to GitHub'


    describe 'reading acessing gitconfig'


    describe 'querying repo infos'


    describe 'working around GitHub\'s \'insteadof\' matching'


    describe 'creating a title and a body for a request'


    describe 'looking up various things'

  end

end
