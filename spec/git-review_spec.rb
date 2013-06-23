require_relative 'spec_helper'
require_relative '../lib/base/commands'
require_relative '../lib/git-review'

describe 'GitReview' do

  let(:cmd) { ::GitReview::Commands }
  let(:gh) { ::GitReview::Github.instance }

  subject { ::GitReview::GitReview }

  it 'shows help page if no arguments are given' do
    subject.any_instance.should_receive(:help)
    subject.new
  end

  it 'shows help page if argument is empty' do
    subject.any_instance.should_receive(:help)
    subject.new(%w())
  end

  it 'checks whether the command is valid' do
    subject.any_instance.stub(:help)
    cmd.should_receive(:respond_to?).with('foo')
    subject.new(%w(foo))
  end

  context 'when command is valid' do

    before(:each) do
      assume_valid_command
      gh.stub(:initialize_local_repo)
      gh.stub(:local_repo).and_return(true)
      gh.stub(:configure_github_access).and_return(true)
    end

    it 'proceeds to execute the command' do
      subject.any_instance.should_receive(:execute_command).with('foo')
      subject.new(%w(foo))
    end

    it 'calls update first if command is not clean' do
      cmd.stub(:send).with('foo')
      gh.should_receive(:update)
      subject.new(%w(foo))
    end

    it 'does not call update if command is clean' do
      cmd.stub(:send).with('clean')
      gh.should_not_receive(:update)
      subject.new(%w(clean))
    end

    it 'actually calls the command' do
      gh.stub(:update)
      cmd.should_receive(:send).with('foo')
      subject.new(%w(foo))
    end

  end

  context 'when command is invalid' do

    before(:each) do
      assume_invalid_command
    end

    it 'notifies the user' do
      subject.any_instance.stub(:help)
      subject.any_instance.should_receive(:puts).
          with(/'foo' is not a valid command/)
      subject.new(%w(foo))
    end

    it 'does not call that command' do
      subject.any_instance.stub(:help)
      cmd.should_not_receive('foo')
      subject.new(%w(foo))
    end

    it 'shows help page' do
      cmd.should_receive(:help)
      subject.new(%w(foo))
    end

  end

end