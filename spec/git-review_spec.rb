require_relative 'spec_helper'
require_relative '../lib/base/commands'
require_relative '../lib/git-review'

describe 'GitReview' do

  let(:cmd) { ::GitReview::Commands }
  let(:gr) { ::GitReview::GitReview }
  let(:gh) { ::GitReview::Github.instance }

  it 'shows help page if no arguments are given' do
    cmd.should_receive(:help)
    gr.new
  end

  it 'shows help page if argument is empty' do
    cmd.should_receive(:help)
    gr.new(%w())
  end

  it 'checks whether the command is valid' do
    cmd.stub(:help)
    cmd.should_receive(:respond_to?).with('foo')
    gr.new(%w(foo))
  end

  context 'when command is valid' do

    it 'calls update first unless command is clean' do
      gr.any_instance.stub(:local_repo_ready).and_return(true)
      gr.any_instance.stub(:github_access_ready).and_return(true)
      cmd.stub(:send).with('foo')
      cmd.stub(:respond_to?).with('foo').and_return(true)
      gh.should_receive(:update)
      gr.new(%w(foo))
    end

    it 'calls the command' do
      gr.any_instance.stub(:local_repo_ready).and_return(true)
      gr.any_instance.stub(:github_access_ready).and_return(true)
      gh.stub(:update)
      cmd.stub(:respond_to?).with('foo').and_return(true)
      cmd.should_receive(:send).with('foo')
      gr.new(%w(foo))
    end

  end

  context 'when command is invalid' do

    it 'notifies the user' do
      cmd.stub(:respond_to?).with('foo').and_return(false)
      cmd.stub(:help)
      gr.any_instance.should_receive(:puts).with(/'foo' is not a valid command/)
      gr.new(%w(foo))
    end

    it 'does not call that command' do
      cmd.stub(:respond_to?).with('foo').and_return(false)
      cmd.stub(:help)
      cmd.should_not_receive('foo')
      gr.new(%w(foo))
    end

    it 'shows help page' do
      cmd.stub(:respond_to?).with('foo').and_return(false)
      cmd.should_receive(:help)
      gr.new(%w(foo))
    end

  end

end