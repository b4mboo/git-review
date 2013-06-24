require_relative '../spec_helper'
require_relative '../../lib/base/local'

describe 'Local' do

  describe 'checking if branch exists' do

    subject { ::GitReview::Local.instance }

    it 'returns false if location is neither local nor remote' do
      subject.branch_exists?(:foo, 'bar').should be_false
    end

    it 'adds prefix to remote branch' do
      subject.stub(:all_branches).and_return(['remotes/origin/foo'])
      subject.branch_exists?(:remote, 'foo').should be_true
    end

    it 'does not add prefix to local branch' do
      subject.stub(:all_branches).and_return(['foo'])
      subject.branch_exists?(:local, 'foo').should be_true
    end

  end

  describe 'deleting a branch' do

    subject { ::GitReview::Local.instance }

    it 'removes a local branch with a given name' do
      branch_name = 'foo'
      assume_branch_exists(:local, branch_name)
      subject.should_receive(:git_call).
          with("branch -D #{branch_name}", true)
      subject.delete_local_branch(branch_name)
    end

    it 'removes a remote branch with a given name' do
      branch_name = 'foo'
      assume_branch_exists(:remote, branch_name)
      subject.should_receive(:git_call).
          with("push origin :#{branch_name}", true)
      subject.delete_remote_branch(branch_name)
    end

    it 'removes both local and remote branches with the same name' do
      branch_name = 'foo'
      assume_branch_exists(:remote, branch_name)
      assume_branch_exists(:local, branch_name)
      subject.should_receive(:git_call).
          with("push origin :#{branch_name}", true)
      subject.should_receive(:git_call).
          with("branch -D #{branch_name}", true)
      subject.delete_branch(branch_name)
    end

  end

  describe 'cleaning all branches' do

  end

end