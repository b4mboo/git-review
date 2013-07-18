require 'hashie'
require_relative '../spec_helper'

describe 'Local' do

  describe '.instance' do

    subject { ::GitReview::Local }

    it 'gives back the same instance' do
      first_call = subject.instance
      second_call = subject.instance
      first_call.should == second_call
    end

  end

  describe '#initialize' do

    subject { ::GitReview::Local }

    it 'raises error when the directory is not a valid git repo' do
      subject.any_instance.stub(:git_call).with('rev-parse --show-toplevel').
          and_return('')
      expect { subject.new }.
          to raise_error(::GitReview::InvalidGitRepositoryError)
    end

  end

  describe '#add_pull_refspec' do

    subject { ::GitReview::Local.new }

    it 'add refspec to local git config when it is not set' do
      refspec = '+refs/pull/*/head:refs/remotes/origin/pr/*'
      new_config = "config --local --add remote.origin.fetch #{refspec}"
      config = 'remote.origin.fetch=+refs/heads/*:refs/remotes/origin/*'
      subject.stub(:config_list).and_return(config)
      subject.should_receive(:git_call).with(new_config, false)
      subject.add_pull_refspec
    end

  end

  describe '#load_config' do

    subject { ::GitReview::Local.new }

    it 'reads config into hash' do
      config = "foo=bar\nbaz=qux"
      subject.stub(:config_list).and_return(config)
      subject.load_config.should == {'foo' => 'bar', 'baz' => 'qux'}
    end

    it 'reads multiple values for a key' do
      config = "foo=bar\nbaz=qux\nfoo=bar2"
      subject.stub(:config_list).and_return(config)
      subject.load_config.should == {'foo' => ['bar', 'bar2'], 'baz' => 'qux'}
    end

  end

  describe '#branch_exists?' do

    subject { ::GitReview::Local.new }

    it 'returns false if location is neither local nor remote' do
      subject.branch_exists?(:foo, 'bar').should be_false
    end

    it 'adds prefix to remote branch' do
      subject.stub(:all_branches).and_return(%w(remotes/origin/foo bar))
      subject.branch_exists?(:remote, 'foo').should be_true
    end

    it 'does not add prefix to local branch' do
      subject.stub(:all_branches).and_return(%w(foo bar))
      subject.branch_exists?(:local, 'foo').should be_true
    end

  end

  describe 'deleting a branch' do

    subject { ::GitReview::Local.new }

    it 'removes a local branch with a given name' do
      branch_name = 'foo'
      subject.stub(:branch_exists?).with(:local, branch_name).and_return(true)
      subject.should_receive(:git_call).
          with("branch -D #{branch_name}", true)
      subject.delete_local_branch(branch_name)
    end

    it 'removes a remote branch with a given name' do
      branch_name = 'foo'
      subject.stub(:branch_exists?).with(:remote, branch_name).and_return(true)
      subject.should_receive(:git_call).
          with("push origin :#{branch_name}", true)
      subject.delete_remote_branch(branch_name)
    end

    it 'removes both local and remote branches with the same name' do
      branch_name = 'foo'
      subject.stub(:branch_exists?).with(:local, branch_name).and_return(true)
      subject.stub(:branch_exists?).with(:remote, branch_name).and_return(true)
      subject.should_receive(:git_call).
          with("push origin :#{branch_name}", true)
      subject.should_receive(:git_call).
          with("branch -D #{branch_name}", true)
      subject.delete_branch(branch_name)
    end

  end

  describe '#clean_single' do

    subject { ::GitReview::Local.new }
    let(:gh) { ::GitReview::Github.any_instance }

    it 'queries latest info for the specific closed request from Github ' do
      request_number = 1
      repo = 'foo'
      subject.stub(:source_repo).and_return(repo)
      gh.should_receive(:pull_request).with(repo, request_number)
      subject.clean_single(request_number)
    end

    it 'does not delete anything if request is not found' do
      invalid_request_number = 123
      gh.stub(:pull_request).and_raise(Octokit::NotFound)
      subject.should_not_receive(:delete_branch)
      subject.clean_single(invalid_request_number)
    end

    it 'does not delete the branch if request is not closed' do
      open_request_number = 123
      request = Hashie::Mash.new({:state => 'open',
                                  :number => open_request_number})
      gh.stub(:pull_request).and_return(request)
      subject.should_not_receive(:delete_branch)
      subject.clean_single(open_request_number)
    end

    it 'deletes branch if request is found and no unmerged commits' do
      subject.stub(:unmerged_commits?).and_return(false)
      request_number = 1
      request = Hashie::Mash.new({:head => {:ref => 'some_branch'},
                                  :state => 'closed'})
      gh.stub(:pull_request).and_return(request)
      subject.should_receive(:delete_branch).with('some_branch')
      subject.clean_single(request_number)
    end

    it 'does not delete branch if there is unmerged commits' do
      subject.stub(:unmerged_commits?).and_return(true)
      request_number = 1
      request = Hashie::Mash.new({:number => request_number})
      gh.stub(:pull_request).and_return(request)
      subject.should_not_receive(:delete_branch)
      subject.clean_single(request_number)
    end

    it 'ignores unmerged commits if force deletion is set' do
      subject.stub(:unmerged_commits?).and_return(true)
      request_number = 1
      request = Hashie::Mash.new({:head => {:ref => 'some_branch'},
                                  :state => 'closed'})
      gh.stub(:pull_request).and_return(request)
      subject.should_receive(:delete_branch)
      subject.clean_single(request_number, force=true)
    end

  end

  describe '#clean_all' do

    subject { ::GitReview::Local.new }
    let(:gh) { ::GitReview::Github.any_instance }

    it 'does not delete protected branches' do
      subject.stub(:unmerged_commits?).and_return(false)
      subject.stub(:protected_branches).and_return(%w(review_foo))
      subject.stub(:review_branches).
          and_return(%w(review_bar review_baz review_foo))
      subject.should_receive(:delete_branch).twice
      subject.should_not_receive(:delete_branch).with('review_foo')
      subject.clean_all
    end

    it 'does not delete branches with unmerged commits' do
      subject.stub(:unmerged_commits?).and_return(true)
      subject.stub(:protected_branches).and_return([])
      subject.stub(:review_branches).and_return(%w(review_foo))
      subject.should_not_receive(:delete_branch).with('review_foo')
      subject.clean_all
    end

  end

  describe '#source_branch' do

    subject { ::GitReview::Local.new }

    it 'extracts source branch' do
      branches = "* master\nreview_branch1\nreview_branch2\n"
      subject.stub(:git_call).with('branch').and_return(branches)
      subject.source_branch.should == 'master'
    end

  end

end