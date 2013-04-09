require 'spec_helper'

describe GitReview do

  subject { GitReview.any_instance }

  it 'shows the help page if no parameters are given' do
    subject.should_receive(:puts).with(
      include('Usage: git review <command>')
    )
    GitReview.new
  end

  it 'tells the user if the given command is invalid' do
    subject.should_receive(:puts).with(include('not a valid command.'))
    GitReview.new(['invalid'])
  end

  it 'collects repository info if a valid command is given'

  it 'configures the GitHub access if repo info is found'

  it 'gets the updates from GitHub before executing a command'

  it 'exits with a warning when an error occurred'

  it 'checks whether a request exists that matches the given ID'

end

