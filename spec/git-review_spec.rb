require 'spec_helper'

describe GitReview do

  subject { GitReview.new }

  it 'shows the help page if no parameters are given' do
    subject.should_receive(:puts).with(include 'Usage: git review <command>')
    subject.init
  end

  it 'tells the user if the given command is invalid' do
    subject.should_receive(:puts).with(include 'not a valid command.')
    assume_valid_command false
    subject.init
  end

  it 'collects repository info if a valid command is given' do
    subject.should_receive(:repo_info)
    assume_valid_command
    subject.init
  end


  it 'configures the GitHub access if repo info is found' do
    subject.should_receive(:repo_info)
    assume_valid_command
    subject.init
  end

  it 'gets the updates from GitHub before executing a command'

  it 'exits with a warning when an error occurred'

  it 'checks whether a request exists that matches the given ID'

end

