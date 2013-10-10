require_relative '../spec_helper'

describe 'Commands' do

  include_context 'request_context'

  subject { ::GitReview::Commands }
  let(:github) { ::GitReview::Github.any_instance }
  let(:local) { ::GitReview::Local.any_instance }

  before :each do
    github.stub(:configure_access).and_return('username')
    subject.stub :puts
  end

  describe 'list (--reverse)'.pink do

    before :each do
      local.stub(:source).and_return('some_source')
    end

    context 'with open pull requests' do

      let(:req1) { request.clone }
      let(:req2) { request.clone }

      before :each do
        req1.title = 'first'
        req2.title = 'second'
        github.stub(:current_requests_full).and_return([req1, req2])
        local.stub(:merged?).and_return(false)
      end

      it 'prints a list of all open requests' do
        subject.should_receive(:puts).with(/Pending requests for 'some_source'/)
        subject.should_not_receive(:puts).with(/No pending requests/)
        subject.should_receive(:print_requests).with([req1, req2], false)
        subject.list
      end

      it 'allows to sort the list by adding ' + '--reverse'.pink do
        subject.stub :puts
        subject.should_receive(:print_requests).with([req1, req2], true)
        subject.list true
      end

    end

    context 'with closed pull requests' do

      before :each do
        github.stub(:current_requests_full).and_return([request])
        local.stub(:merged?).and_return(true)
      end

      it 'ignores closed requests and does not list them' do
        subject.should_receive(:puts).
          with(/No pending requests for 'some_source'/)
        subject.should_not_receive :print_request
        subject.list
      end

    end

    context 'without pull requests' do

      before :each do
        github.stub(:current_requests_full).and_return([])
      end

      it 'does not print a list when there are no requests' do
        subject.should_receive(:puts).
          with(/No pending requests for 'some_source'/)
        subject.should_not_receive :print_request
        subject.list
      end

    end

  end

  describe 'show ID (--full)'.pink do

    before :each do
      github.stub(:request_exists?).and_return(request)
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      github.stub(:request_exists?).and_return(false)
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
      github.stub(:request_exists?).and_return(request)
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      github.stub(:request_exists?).and_return(false)
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
      github.stub(:request_exists?).and_return(request)
    end

    it 'requires a valid request number as ' + 'ID'.pink do
      github.stub(:request_exists?).and_return(false)
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

    it 'prints an info text if the user is already on the right branch' do
      local.stub(:branch_exists?).with(:local, branch_name).and_return(true)
      local.should_receive(:source_branch).and_return(branch_name)
      subject.should_receive(:puts).with("On branch #{branch_name}.")
      subject.checkout(request_number)
    end

  end

  describe 'approve ID'.pink do

    before(:each) do
      github.stub(:get_request_by_number).and_return(request)
      github.stub(:source_repo).and_return('some_source')
    end

    it 'posts an approving comment in your name to the requests page' do
      comment = 'Reviewed and approved.'
      github.should_receive(:add_comment).
        with('some_source', request_number, 'Reviewed and approved.').
        and_return(body: comment)
      subject.should_receive(:puts).with(/Successfully approved request./)
      subject.approve(1)
    end

    it 'outputs any errors that might occur when trying to post a comment' do
      message = 'fail'
      github.should_receive(:add_comment).
        with('some_source', request_number, 'Reviewed and approved.').
        and_return(body: nil, message: message)
      subject.should_receive(:puts).with(message)
      subject.approve(1)
    end

  end

  describe 'merge ID'.pink do

    before(:each) do
      github.stub(:get_request_by_number).and_return(request)
      github.stub(:source_repo)
    end

    it 'does not proceed if source repo no longer exists' do
      request.head.stub(:repo).and_return(nil)
      subject.should_receive(:print_repo_deleted)
      subject.should_not_receive(:git_call)
      subject.merge(1)
    end

    it 'merges the request with your current branch' do
      msg = "Accept request ##{request_number} " +
          "and merge changes into \"/master\""
      subject.should_receive(:git_call).with("merge -m '#{msg}' #{head_sha}")
      subject.merge(1)
    end

  end

  describe 'close ID'.pink do

    before(:each) do
      github.stub(:get_request_by_number).and_return(request)
      github.stub(:source_repo).and_return('some_source')
    end

    it 'closes the request' do
      github.should_receive(:close_issue).with('some_source', request_number)
      github.should_receive(:request_exists?).
          with('open', request_number).and_return(false)
      subject.should_receive(:puts).with(/Successfully closed request./)
      subject.close(1)
    end

  end

  describe 'prepare'.pink do

    context 'when on master/target branch' do

      before(:each) do
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

    end

    context 'when on feature branch' do

      before(:each) do
        local.stub(:source_branch).and_return(branch_name)
        local.stub(:target_branch).and_return('master')
        subject.stub(:git_call)
        subject.stub(:create_feature_name).and_return(branch_name)
      end

      it 'moves uncommitted changes to the new branch' do
        local.stub(:uncommitted_changes?).and_return(true)
        subject.should_receive(:git_call).with('stash')
        subject.should_receive(:git_call).with('reset --hard origin/master')
        subject.send(:move_uncommitted_changes, 'master', feature_name)
      end

    end

  end

  describe 'create'.pink do

    before(:each) do
      subject.stub(:prepare).and_return(['master', branch_name])
    end

    context 'when sending pull request to current repo' do

      before(:each) do
        local.stub(:source_branch).and_return(branch_name)
        local.stub(:target_branch).and_return('master')
        local.stub(:new_commits?).with(false).and_return(true)
      end

      context 'when there are uncommitted changes' do

        before(:each) do
          local.stub(:uncommitted_changes?).and_return(true)
        end

        it 'warns the user about uncommitted changes' do
          subject.should_receive(:puts).with(/uncommitted changes/)
          subject.create
        end

      end

      context 'when there are no uncommitted changes' do

        before(:each) do
          local.stub(:uncommitted_changes?).and_return(false)
          subject.stub(:git_call)
        end

        it 'pushes the commits to a remote branch and creates a pull request' do
          github.stub(:request_exists_for_branch?).and_return(false)
          subject.should_receive(:git_call).with(
              "push --set-upstream origin #{branch_name}", false, true
          )
          subject.should_receive(:create_pull_request)
          subject.create
        end

        it 'does not create pull request if it already exists for the branch' do
          github.stub(:request_exists_for_branch?).with(false).and_return(true)
          subject.should_not_receive(:create_pull_request)
          subject.should_receive(:puts).with(/already exists/)
          subject.should_receive(:puts).with(/`git push`/)
          subject.create(false)
        end

        it 'lets the user return to the branch she was working on before' do
          github.stub(:request_exists_for_branch?).and_return(false)
          subject.stub(:create_pull_request)
          subject.should_receive(:git_call).with('checkout master')
          subject.create
        end

      end

    end

    context 'when sending pull request to upstream repo' do

      let(:upstream) {
        Hashie::Mash.new(parent: {full_name: 'upstream'})
      }

      before(:each) do
        local.stub(:source_branch).and_return(branch_name)
        local.stub(:target_branch).and_return('master')
        local.stub(:uncommitted_changes?).and_return(false)
        github.stub(:repository).and_return(upstream)
        subject.stub(:git_call)
      end

      it 'does not create pull request if one already exists for the branch' do
        local.stub(:new_commits?).and_return(true)
        github.stub(:request_exists_for_branch?).with(true).and_return(true)
        subject.should_not_receive(:create_pull_request)
        subject.should_receive(:puts).with(/already exists/)
        subject.should_receive(:puts).with(/`git push`/)
        subject.create(true)
      end

      it 'checks if current branch differ from upstream master' do
        local.should_receive(:new_commits?).with(true).and_return(false)
        subject.should_not_receive(:create_pull_request)
        subject.create(true)
      end

    end

  end

  describe '#create_pull_request' do

    before(:each) do
      github.stub(:latest_request_number).and_return(1)
      subject.stub(:create_title_and_body).and_return(['title', 'body'])
      local.stub(:target_repo).and_return('parent:repo')
      local.stub(:head).and_return('local:repo')
      local.stub(:target_branch).and_return('master')
      subject.stub(:git_call)
    end

    it 'sends pull request to upstream repo' do
      github.should_receive(:create_pull_request).
          with('parent:repo', 'master', 'local:repo', 'title', 'body')
      github.stub(:request_number_by_title).and_return(2)
      subject.should_receive(:puts).with(/Successfully/)
      subject.should_receive(:puts).with(/pull\/2/)
      subject.send(:create_pull_request, true)
    end

    it 'checks if pull request is indeed created' do
      github.should_receive(:create_pull_request).
          with('parent:repo', 'master', 'local:repo', 'title', 'body')
      github.stub(:request_number_by_title).and_return(nil)
      subject.should_receive(:puts).with(/not created for parent:repo/)
      subject.send(:create_pull_request, true)
    end

  end

  describe 'clean ID (--force) / --all'.pink do

    before :each do
      subject.stub(:git_call).with(include 'checkout')
      local.stub :clean_remotes
      local.stub(:target_branch).and_return(target_branch)
    end

    it 'switches back to the target branch (mostly master)' do
      subject.should_receive(:git_call).with("checkout #{target_branch}")
      local.should_receive :clean_all
      subject.clean(nil, false, true)
    end

    it 'removes a single obsolete branch with review prefix' do
      local.should_receive(:clean_single).with(request_number, false)
      subject.clean request_number
    end

    it 'removes all obsolete branches with review prefix' do
      local.should_receive :clean_all
      subject.clean(nil, false, true)
    end

    it 'deletes a branch with unmerged changes with --force option' do
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
