require_relative 'spec_helper'

describe 'GitReview' do

  let(:cmd) { ::GitReview::Commands }
  let(:gh) { ::GitReview::Github.any_instance }

  subject { ::GitReview::GitReview }

  describe '#initialize' do

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

    it 'stores arguments in Commands' do
      cmd.stub(:respond_to?).and_return(true)
      subject.any_instance.stub(:execute_command)
      subject.new(%w(foo bar baz))
      cmd.args.should == %w(bar baz)
    end

  end

  context 'when command is valid' do

    before(:each) do
      cmd.stub(:respond_to?).and_return(true)
      gh.stub(:configure_github_access).and_return(true)
      gh.stub(:source_repo).and_return('foo')
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
      cmd.stub(:respond_to?).and_return(false)
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