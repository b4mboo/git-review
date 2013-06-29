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

  describe 'cleaning obsolete branch for a single request' do

    subject { ::GitReview::Local.instance }

    it 'queries latest info for the specific closed request from Github ' do
      request_id = 1
      ::GitReview::Github.instance.should_receive(:get_request).
          with('closed', request_id)
      subject.clean_single(request_id)
    end

    it 'does not delete anything if request is not found' do
      ::GitReview::Github.instance.stub(:get_request).and_return(nil)
      subject.should_not_receive(:delete_branch)
      subject.clean_single(1)
    end

    it 'deletes branch if request is found and no unmerged commits' do
      assume_no_unmerged_commits
      request = ::GitReview::Request.new({:head => {:ref => 'some_branch'}})
      ::GitReview::Github.instance.stub(:get_request).and_return(request)
      subject.should_receive(:delete_branch).with('some_branch')
      subject.clean_single(1)
    end

    it 'does not delete branch if there is unmerged commits' do
      assume_unmerged_commits
      request = ::GitReview::Request.new
      ::GitReview::Github.instance.stub(:get_request).and_return(request)
      subject.should_not_receive(:delete_branch)
      subject.clean_single(1)
    end

    it 'ignores unmerged commits if force deletion is set' do
      assume_unmerged_commits
      request = ::GitReview::Request.new({:head => {:ref => 'some_branch'}})
      ::GitReview::Github.instance.stub(:get_request).and_return(request)
      subject.should_receive(:delete_branch).with('some_branch')
      subject.clean_single(1, force=true)
    end

  end

  describe 'cleaning all obsolete branches' do

    subject { ::GitReview::Local.instance }

    it 'queries latest info from Github' do
      subject.stub(:protected_branches).and_return([])
      subject.stub(:review_branches).and_return([])
      ::GitReview::Github.instance.should_receive(:update)
      subject.clean_all
    end

    it 'does not delete protected branches' do
      assume_updated
      assume_no_unmerged_commits
      subject.stub(:protected_branches).and_return(%w(review_foo))
      subject.stub(:review_branches).
          and_return(%w(review_bar review_baz review_foo))
      subject.should_receive(:delete_branch).twice
      subject.should_not_receive(:delete_branch).with('review_foo')
      subject.clean_all
    end

    it 'does not delete branches with unmerged commits' do
      assume_updated
      assume_unmerged_commits
      subject.stub(:protected_branches).and_return([])
      subject.stub(:review_branches).and_return(%w(review_foo))
      subject.should_not_receive(:delete_branch).with('review_foo')
      subject.clean_all
    end

  end

end