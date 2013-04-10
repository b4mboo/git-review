require 'spec_helper'

describe GitReview do

  subject { GitReview.new }

  let(:user) { 'user' }
  let(:repo) { 'repo' }
  let(:command) { 'command' }


  describe 'initially' do

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

end
