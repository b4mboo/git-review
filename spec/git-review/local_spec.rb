require 'hashie'
require_relative '../spec_helper'

describe 'Local' do

  subject { ::GitReview::Local.new }

  before :each do
    ::GitReview::Provider::Github.any_instance.stub :configure_oauth
  end

  describe '.instance' do

    it 'gives back the same instance' do
      first_call = ::GitReview::Local.instance
      second_call = ::GitReview::Local.instance
      first_call.should eq second_call
    end

  end

  describe 'handling remotes' do

    include_context 'request_context'
    let(:server) { double :server }

    it 'lists all locally configured remotes' do
      subject.should_receive(:git_call).with('remote').
        and_return("origin\n#{remote}\n")
      subject.remotes.should == ['origin', remote]
    end

    it 'determines whether a remote already exists' do
      subject.should_receive(:remotes).and_return([remote])
      subject.remote_exists?(remote).should be_true
    end

    it 'knows the remotes\'s with their respective urls' do
      subject.should_receive(:git_call).with('remote -vv').and_return(
        "#{remote}\t#{remote_url} (fetch)\n#{remote}\t#{remote_url} (push)\n"
      )
      subject.remotes_with_urls.should == {
        remote => { fetch: remote_url, push: remote_url }
      }
    end

    it 'knows all remotes for existing local branches' do
      subject.should_receive(:git_call).with('branch -lvv').and_return(
        "* review_000000_foobar        00aa0aa [#{remote}/review_000000_foobar] Foo!\n"
      )
      subject.remotes_for_branches.should == [remote]
    end

    it 'finds existing remotes for a given url' do
      subject.should_receive(:remotes_with_urls).
        and_return(remote => { fetch: remote_url, push: remote_url })
      subject.remotes_for_url(remote_url).should == [remote]
    end

    it 'finds an existing remote for a request' do
      subject.stub(:server).and_return(server)
      server.should_receive(:remote_url_for).
        with(user_login).and_return(remote_url)
      subject.should_receive(:remotes_for_url).
        with(remote_url).and_return([remote])
      subject.remote_for_request(request).should == remote
    end

    it 'adds a new remote for a request if necessary' do
      subject.stub(:server).and_return(server)
      server.should_receive(:remote_url_for).
        with(user_login).and_return(remote_url)
      subject.should_receive(:remotes_for_url).
        with(remote_url).and_return([])
      subject.should_receive(:git_call).
        with("remote add review_#{user_login} #{remote_url}", false, true)
      subject.remote_for_request(request).should == remote
    end

    it 'finds an existing remote for a branch' do
      cmd = "for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD)"
      subject.should_receive(:git_call).with(cmd).and_return(
        "#{remote}/#{branch_name}\n"
      )
      subject.remote_for_branch(branch_name).should == remote
    end

    it 'returns nil for a local branch without a remote' do
      cmd = "for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD)"
      subject.should_receive(:git_call).with(cmd).
        and_return("\n")
      subject.remote_for_branch(branch_name).should == nil
    end

    it 'removes obsolete remotes with review prefix when cleaning up' do
      subject.should_receive(:remotes).and_return([remote])
      subject.should_receive(:remotes_for_branches).and_return([])
      subject.should_receive(:git_call).with("remote remove #{remote}")
      subject.clean_remotes
    end

    it 'keeps review remotes if there is a local branch referencing it' do
      subject.should_receive(:remotes).and_return([remote])
      subject.should_receive(:remotes_for_branches).and_return([remote])
      subject.should_not_receive(:git_call).with("remote remove #{remote}")
      subject.clean_remotes
    end

    it 'keeps review remotes if they have no review prefix' do
      remote = 'origin'
      subject.should_receive(:remotes).and_return([remote])
      subject.should_receive(:remotes_for_branches).and_return([])
      subject.should_not_receive(:git_call).with("remote remove #{remote}")
      subject.clean_remotes
    end

    it 'prunes all configured remotes' do
      subject.should_receive(:remotes).and_return([remote])
      subject.should_receive(:git_call).with("remote prune #{remote}")
      subject.prune_remotes
    end

  end

  describe '#initialize' do

    it 'raises error when the directory is not a valid git repo' do
      ::GitReview::Local.any_instance.stub(:git_call).
          with('rev-parse --show-toplevel').and_return('')
      expect { ::GitReview::Local.new }.
          to raise_error(::GitReview::InvalidGitRepositoryError)
    end

  end

  describe '#load_config' do

    it 'reads config into hash' do
      config = "foo=bar\nbaz=qux"
      subject.stub(:config_list).and_return(config)
      subject.load_config.should eq({'foo' => 'bar', 'baz' => 'qux'})
    end

    it 'reads multiple values for a key' do
      config = "foo=bar\nbaz=qux\nfoo=bar2"
      subject.stub(:config_list).and_return(config)
      subject.load_config.should eq({'foo' => ['bar', 'bar2'], 'baz' => 'qux'})
    end

    it 'does not keep duplicate values for a key' do
      config = "foo=bar\nbaz=qux\nfoo=bar"
      subject.stub(:config_list).and_return(config)
      subject.load_config.should eq({'foo' => 'bar', 'baz' => 'qux'})
    end

  end

  describe '#branch_exists?' do

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

    it 'removes the asterisk from the current branch' do
      subject.should_receive(:git_call).with('branch -a').
        and_return("  master\n  * other\n")
      subject.all_branches.should == ['master', 'other']
    end

  end

  describe 'deleting a branch' do

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

    let(:server) { ::GitReview::Server.any_instance }

    before :each do
      server.stub(:configure_access).and_return('username')
    end

    it 'queries latest info for the specific closed request from provider ' do
      request_number = 1
      repo = 'foo'
      subject.stub(:source_repo).and_return(repo)
      server.should_receive(:pull_request).with(repo, request_number)
      subject.clean_single(request_number)
    end

    it 'does not delete anything if request is not found' do
      invalid_request_number = 123
      server.stub(:pull_request).and_raise(Octokit::NotFound)
      subject.should_not_receive(:delete_branch)
      subject.clean_single(invalid_request_number)
    end

    it 'does not delete the branch if request is not closed' do
      open_request_number = 123
      request = Hashie::Mash.new({state: 'open',
                                  number: open_request_number})
      server.stub(:pull_request).and_return(request)
      subject.should_not_receive(:delete_branch)
      subject.clean_single(open_request_number)
    end

    it 'deletes branch if request is found and no unmerged commits' do
      subject.stub(:unmerged_commits?).and_return(false)
      request_number = 1
      request = Hashie::Mash.new({head: {ref: 'some_branch'},
                                  state: 'closed'})
      server.stub(:pull_request).and_return(request)
      subject.should_receive(:delete_branch).with('some_branch')
      subject.clean_single(request_number)
    end

    it 'does not delete branch if there is unmerged commits' do
      subject.stub(:unmerged_commits?).and_return(true)
      request_number = 1
      request = Hashie::Mash.new({number: request_number})
      server.stub(:pull_request).and_return(request)
      subject.should_not_receive(:delete_branch)
      subject.clean_single(request_number)
    end

    it 'ignores unmerged commits if force deletion is set' do
      request_number = 1
      request = Hashie::Mash.new({
        head: {ref: 'some_branch'},
        state: 'closed'
      })

      subject.stub(:unmerged_commits?).and_return(true)
      server.stub(:pull_request).and_return(request)
      subject.should_receive(:delete_branch)
      subject.clean_single(request_number, true)
    end

  end

  describe '#clean_all' do

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

    it 'extracts source branch' do
      branches = "* master\nreview_branch1\nreview_branch2\n"
      subject.stub(:git_call).with('branch').and_return(branches)
      subject.source_branch.should == 'master'
    end

  end

  describe '#merged?' do

    let(:sha) { '1234abcd' }

    it 'finds all branches containing the commit' do
      subject.should_receive(:git_call).with(/branch --contains #{sha}/).
          and_return('')
      subject.merged?(sha)
    end

    it 'confirms merged if target branch contains the commit' do
      subject.stub(:target_branch).and_return('master')
      subject.stub(:git_call).and_return("* master\n some_other_branch\n")
      subject.merged?(sha).should be_true
    end

  end

  it 'sanitizes branch names' do
    subject.sanitize_branch_name('Wild Stuff !').should == 'wild_stuff_'
  end

end
