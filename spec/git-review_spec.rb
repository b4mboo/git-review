require_relative 'spec_helper'
require_relative '../lib/base/commands'
require_relative '../lib/git-review'

describe 'GitReview' do

  context 'command' do

      let(:cmd) { ::GitReview::Commands }
      let(:gr) { ::GitReview::GitReview }
      let(:gh) { ::GitReview::Github.instance }

      it 'calls help when nil' do
        cmd.should_receive(:help)
        gr.new([nil])
      end

      it 'calls help when empty' do
        cmd.should_receive(:help)
        gr.new(%w())
      end

      it 'checks for validity' do
        cmd.stub(:help)
        cmd.should_receive(:respond_to?).with('foo')
        gr.new(%w(foo))
      end

    it 'calls command if valid' do
      gr.any_instance.stub(:local_repo_ready).and_return(true)
      gr.any_instance.stub(:github_access_ready).and_return(true)
      gh.stub(:update)
      cmd.stub(:respond_to?).with('foo').and_return(true)
      cmd.should_receive(:send).with('foo')
      gr.new(%w(foo))
    end

    it 'does not call invalid command' do
      cmd.stub(:respond_to?).with('foo').and_return(false)
      cmd.stub(:help)
      cmd.should_not_receive('foo')
      gr.new(%w(foo))
    end

    it 'calls help if invalid' do
      cmd.stub(:respond_to?).with('foo').and_return(false)
      cmd.should_receive(:help)
      gr.new(%w(foo))
    end

    it 'calls update first unless command is clean' do
      gr.any_instance.stub(:local_repo_ready).and_return(true)
      gr.any_instance.stub(:github_access_ready).and_return(true)
      cmd.stub(:send).with('foo')
      cmd.stub(:respond_to?).with('foo').and_return(true)
      gh.should_receive(:update)
      gr.new(%w(foo))
    end

  end

end