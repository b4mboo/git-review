require_relative '../spec_helper'

describe 'Commands' do

  include_context 'request_context'

  subject { ::GitReview::Commands }
  let(:server) { ::GitReview::Server.any_instance }
  let(:provider) { ::GitReview::Provider::Github.any_instance }
  let(:local) { ::GitReview::Local.any_instance }

  before :each do
    provider.stub(:configure_access).and_return('username')
    subject.stub :puts
  end

  describe 'list (--reverse)'.pink do

    let(:req1) { request.clone }
    let(:req2) { request.clone }

    before :each do
      local.stub(:source).and_return('some_source')
    end

    it 'prints a list of all open requests' do
      server.stub(:current_requests_full).and_return([req1, req2])
      local.stub(:merged?).and_return(false)
      subject.should_receive(:puts).with(/Pending requests for 'some_source'/)
      subject.should_not_receive(:puts).with(/No pending requests/)
      subject.should_receive(:print_requests).with([req1, req2], false)
      subject.list
    end

    it 'allows to sort the list by adding ' + '--reverse'.pink do
      server.stub(:current_requests_full).and_return([req1, req2])
      local.stub(:merged?).and_return(false)
      subject.should_receive(:print_requests).with([req1, req2], true)
      subject.list true
    end

    it 'ignores closed requests and does not list them' do
      server.stub(:current_requests_full).and_return([request])
      local.stub(:merged?).and_return(true)
      subject.should_receive(:puts).with(/No pending requests for 'some_source'/)
      subject.should_not_receive :print_request
      subject.list
    end

    it 'does not print a list when there are no requests' do
      server.stub(:current_requests_full).and_return([])
      subject.should_receive(:puts).with(/No pending requests for 'some_source'/)
      subject.should_not_receive :print_request
      subject.list
    end

  end

  describe 'show ID (--full)'.pink do

    before :each do
      provider.stub(:request_exists?).and_return(request)
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      provider.stub(:request_exists?).and_return(false)
      expect { subject.show invalid_number }.
        to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'shows the request\'s stats' do
      subject.should_receive(:git_call).
        with("diff --color=always --stat HEAD...#{head_sha}")
      subject.stub :print_request_details
      subject.stub :print_request_discussions
      subject.show request_number
    end

    it 'shows the request\'s full diff when adding ' + '--full'.pink do
      subject.should_receive(:git_call).
        with("diff --color=always HEAD...#{head_sha}")
      subject.stub :print_request_details
      subject.stub :print_request_discussions
      subject.show(request_number, true)
    end

  end

  describe 'browse ID'.pink do

    before :each do
      provider.stub(:request_exists?).and_return(request)
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      provider.stub(:request_exists?).and_return(false)
      expect { subject.browse invalid_number }.
        to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'opens a browser at the provider\'s page for the pull request' do
      request.stub_chain(:_links, :html, :href).and_return(html_url)
      Launchy.should_receive(:open).with(html_url)
      subject.browse request_number
    end

  end

  describe 'checkout ID (--no-branch)'.pink do

    before :each do
      local.stub(:remote_for_request).with(request).and_return(remote)
      subject.stub(:git_call).with("fetch #{remote}")
      provider.stub(:request_exists?).and_return(request)
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      provider.stub(:request_exists?).and_return(false)
      expect { subject.checkout invalid_number }.
        to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'creates a branch on the local repo with the request\'s code' do
      local.stub(:branch_exists?).with(:local, branch_name).and_return(true)
      subject.should_receive(:git_call).with("checkout #{branch_name}")
      subject.checkout request_number
    end

    it 'switches branches if the branch already exists locally' do
      local.stub(:branch_exists?).with(:local, branch_name).and_return(false)
      subject.should_receive(:git_call).
        with("checkout --track -b #{branch_name} #{remote}/#{branch_name}")
      subject.checkout request_number
    end

    it 'prints an info text if the user is already on the right branch' do
      local.stub(:branch_exists?).with(:local, branch_name).and_return(true)
      local.should_receive(:source_branch).and_return(branch_name)
      subject.should_receive(:puts).with("On branch #{branch_name}.")
      subject.checkout request_number
    end

    it 'optionally creates a headless state by adding ' + '--no-branch'.pink do
      subject.should_receive(:git_call).with("checkout #{remote}/#{branch_name}")
      subject.checkout(request_number, false)
    end

    it 'adds a new remote if the request originates from a fork' do
      local.should_receive(:remote_for_request).with(request).and_return(remote)
      subject.should_receive(:git_call).with("fetch #{remote}")
      subject.should_receive(:git_call).with("checkout #{remote}/#{branch_name}")
      subject.checkout(request_number, false)
    end

  end

  describe 'approve ID'.pink do

    let(:comment) { 'Reviewed and approved.' }

    before :each do
      provider.stub(:request_exists?).and_return(request)
      server.stub(:source_repo).and_return(head_repo)
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      provider.stub(:request_exists?).and_return(false)
      expect { subject.approve invalid_number }.
        to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'posts an approving comment in your name to the request\'s page' do
      server.should_receive(:add_comment).
        with(head_repo, request_number, comment).and_return(body: comment)
      subject.should_receive(:puts).with(/Successfully approved request./)
      subject.approve request_number
    end

    it 'outputs any errors that might occur when trying to post a comment' do
      message = 'fail'
      server.should_receive(:add_comment).
        with(head_repo, request_number, comment).
        and_return(body: nil, message: message)
      subject.should_receive(:puts).with(message)
      subject.approve request_number
    end

  end

  describe 'merge ID'.pink do

    before :each do
      provider.stub(:request_exists?).and_return(request)
      server.stub :source_repo
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      provider.stub(:request_exists?).and_return(false)
      expect { subject.merge invalid_number }.
        to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'merges the request with your current branch' do
      local.stub(:target).and_return(target_branch)
      msg = "Accept request ##{request_number} " +
        "and merge changes into \"#{target_branch}\""
      subject.should_receive(:git_call).with("merge -m '#{msg}' #{head_sha}")
      subject.merge request_number
    end

    it 'does not proceed if the source repo no longer exists' do
      request.head.stub(:repo).and_return(nil)
      subject.should_receive :print_repo_deleted
      subject.should_not_receive :git_call
      subject.merge request_number
    end

  end

  describe 'close ID'.pink do

    before :each do
      provider.stub(:request_exists?).and_return(request)
      server.stub(:source_repo).and_return(head_repo)
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      provider.stub(:request_exists?).and_return(false)
      expect { subject.close invalid_number }.
        to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'closes an open request' do
      server.should_receive(:close_issue).with(head_repo, request_number)
      server.should_receive(:request_exists?).
          with(state, request_number).and_return(false)
      subject.should_receive(:puts).with(/Successfully closed request./)
      subject.close request_number
    end

  end

  describe 'prepare'.pink do

    before :each do
      local.stub(:source_branch).and_return('master')
      local.stub(:target_branch).and_return('master')
      subject.stub(:git_call)
      subject.stub(:create_feature_name).and_return(branch_name)
    end

    it 'creates a local branch with review prefix' do
      subject.should_receive(:git_call).with("checkout -b #{branch_name}")
      subject.prepare(true, feature_name)
    end

    it 'lets the user choose a name for the branch' do
      subject.should_receive(:gets).and_return(feature_name)
      subject.should_receive(:git_call).with("checkout -b #{branch_name}")
      subject.prepare
    end

    it 'creates a local branch when TARGET_BRANCH is defined' do
      ENV.stub(:[]).with('TARGET_BRANCH').and_return(custom_target_name)
      subject.should_receive(:git_call).with("checkout -b #{branch_name}")
      subject.prepare(true, feature_name)
    end

    it 'sanitizes provided branch names' do
      subject.stub(:gets).and_return('wild stuff')
      subject.send(:get_branch_name).should == 'wild_stuff'
    end

    it 'moves uncommitted changes to the new branch' do
      local.stub(:source_branch).and_return(branch_name)
      local.stub(:target_branch).and_return('master')
      subject.stub(:git_call)
      subject.stub(:create_feature_name).and_return(branch_name)
      local.stub(:uncommitted_changes?).and_return(true)
      subject.should_receive(:git_call).with('stash')
      subject.should_receive(:git_call).with('reset --hard origin/master')
      subject.send(:move_uncommitted_changes, 'master', feature_name)
    end

  end

  describe 'create (--upstream)'.pink do

    let(:upstream) { Hashie::Mash.new(parent: {full_name: 'upstream'}) }

    before :each do
      subject.stub(:prepare).and_return(['master', branch_name])
      local.stub(:source_branch).and_return(branch_name)
      local.stub(:target_branch).and_return('master')
      local.stub(:uncommitted_changes?).and_return(false)
      subject.stub(:git_call)
      local.stub(:new_commits?).with(false).and_return(true)
    end

    it 'warns the user about uncommitted changes' do
      local.stub(:uncommitted_changes?).and_return(true)
      subject.should_receive(:puts).with(/uncommitted changes/)
      subject.create
    end

    it 'pushes the commits to a remote branch and creates a pull request' do
      server.stub(:request_exists_for_branch?).and_return(false)
      subject.should_receive(:git_call).with(
          "push --set-upstream origin #{branch_name}", false, true
      )
      server.should_receive :send_pull_request
      subject.create
    end

    it 'does not create pull request if it already exists for the branch' do
      server.stub(:request_exists_for_branch?).with(false).and_return(true)
      server.should_not_receive :send_pull_request
      subject.should_receive(:puts).with(/already exists/)
      subject.should_receive(:puts).with(/`git push`/)
      subject.create(false)
    end

    it 'lets the user return to the branch she was working on before' do
      server.stub(:request_exists_for_branch?).and_return(false)
      server.stub :send_pull_request
      subject.should_receive(:git_call).with('checkout master')
      subject.create
    end

    it 'does not create pull request if one already exists for the branch' + '--upstream'.pink do
      server.stub(:repository).and_return(upstream)
      local.stub(:new_commits?).and_return(true)
      server.stub(:request_exists_for_branch?).with(true).and_return(true)
      server.should_not_receive :send_pull_request
      subject.should_receive(:puts).with(/already exists/)
      subject.should_receive(:puts).with(/`git push`/)
      subject.create(true)
    end

    it 'checks if current branch differ from upstream master' + '--upstream'.pink do
      server.stub(:repository).and_return(upstream)
      local.should_receive(:new_commits?).with(true).and_return(false)
      server.should_not_receive :send_pull_request
      subject.create(true)
    end

  end

  describe 'clean ID (--force) / --all'.pink do

    before :each do
      subject.stub(:git_call).with(include 'checkout')
      local.stub :clean_remotes
      local.stub :prune_remotes
      local.stub(:target_branch).and_return(target_branch)
    end

    it 'allows only valid request numbers as ' + 'ID'.pink do
      provider.stub(:request_exists?).and_return(false)
      expect { subject.close invalid_number }.
        to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'switches back to the target branch (mostly master)' do
      subject.should_receive(:git_call).with("checkout #{target_branch}")
      local.should_receive :clean_all
      subject.clean(nil, false, true)
    end

    it 'prunes all existing remotes' do
      local.should_receive(:prune_remotes)
      local.should_receive :clean_all
      subject.clean(nil, false, true)
    end

    it 'removes a single obsolete branch with review prefix' do
      local.should_receive(:clean_single).with(request_number, false)
      subject.clean request_number
    end

    it 'removes all obsolete branches with review prefix when using ' + '--all'.pink do
      local.should_receive :clean_all
      subject.clean(nil, false, true)
    end

    it 'deletes a branch with unmerged changes when using ' + '--force'.pink do
      local.should_receive(:clean_single).with(request_number, true)
      subject.clean(request_number, true)
    end

    it 'cleans up remotes' do
      local.should_receive :clean_remotes
      local.should_receive :clean_all
      subject.clean(nil, false, true)
    end

  end

end
