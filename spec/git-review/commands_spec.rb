require_relative '../spec_helper'
require_relative '../support/request_context'

describe 'Commands' do

  include_context 'request_context'

  subject { ::GitReview::Commands }
  let(:github) { ::GitReview::Github.any_instance }
  let(:local) { ::GitReview::Local.any_instance }

  describe '#help' do

    it 'shows the help page' do
      subject.should_receive(:puts).with(/Usage: git review <command>/)
      subject.help
    end

  end

  describe '#list' do

    context 'when listing all unmerged pull requests' do

      before(:each) do
        github.stub(:current_requests_full).and_return([request, request])
        local.stub(:merged?).and_return(false)
        local.stub(:source).and_return('some_source')
        request.stub(:title).and_return('first', 'second')
      end

      it 'shows them' do
        subject.stub(:next_arg).and_return(nil)
        subject.should_receive(:puts).with(/Pending requests for 'some_source'/)
        subject.should_not_receive(:puts).with(/No pending requests/)
        subject.should_receive(:puts).with(/first/).ordered
        subject.should_receive(:puts).with(/second/).ordered
        subject.list
      end

      it 'sorts the output with --reverse option' do
        subject.stub(:next_arg).and_return('--reverse')
        subject.should_receive(:puts).with(/Pending requests for 'some_source'/)
        subject.should_receive(:puts).with(/second/).ordered
        subject.should_receive(:puts).with(/first/).ordered
        subject.list
      end

    end

    context 'when pull requests are already merged' do

      it 'does not list them' do
        github.stub(:current_requests_full).and_return([request])
        local.stub(:merged?).and_return(true)
        local.stub(:source).and_return('some_source')
        subject.should_receive(:puts).
            with(/No pending requests for 'some_source'/)
        subject.should_not_receive(:puts).with(/Pending requests/)
        subject.list
      end

    end

    it 'knows when there are no open pull requests' do
      github.stub(:current_requests_full).and_return([])
      local.stub(:merged?).and_return(true)
      local.stub(:source).and_return('some_source')
      subject.should_receive(:puts).
          with(/No pending requests for 'some_source'/)
      subject.should_not_receive(:puts).with(/Pending requests/)
      subject.list
    end

  end

  describe '#show' do

    it 'requires an ID' do
      subject.stub(:next_arg).and_return(nil)
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.show
    end

    it 'requires a valid request number' do
      subject.stub(:next_arg).and_return(0)
      github.stub(:request_exists?).and_return(false)
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.show
    end

    context 'when the pull request number is valid' do

      before(:each) do
        subject.stub(:next_arg).and_return(1)
        github.stub(:request_exists?).and_return(request)
      end

      it 'shows stats of the request' do
        subject.should_receive(:git_call).
            with("diff --color=always --stat HEAD...#{head_sha}")
        subject.stub(:puts)
        github.stub(:discussion)
        subject.show
      end

      it 'shows full diff with --full option' do
        subject.stub(:next_arg).and_return('--full')
        subject.should_receive(:git_call).
            with("diff --color=always HEAD...#{head_sha}")
        subject.stub(:puts)
        github.stub(:discussion)
        subject.show
      end

    end

  end

  describe '#browse' do

    it 'requires an valid ID' do
      subject.stub(:next_arg).and_return(nil)
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.browse
    end

    it 'opens the pull request page on GitHub in a browser' do
      subject.stub(:next_arg)
      github.stub(:request_exists?).and_return(request)
      Launchy.should_receive(:open).with(html_url)
      subject.browse
    end

  end

  describe '#checkout' do

    it 'requires an valid ID' do
      subject.stub(:next_arg).and_return(nil)
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.checkout
    end

    context 'when the request is valid' do

      before(:each) do
        github.stub(:request_exists?).and_return(request)
      end

      it 'creates a headless state in the local repo with the requests code' do
        subject.stub(:next_arg)
        subject.should_receive(:git_call).with("checkout pr/#{request_number}")
        subject.checkout
      end

      it 'creates a local branch if the optional param --branch is appended' do
        subject.stub(:next_arg).and_return('--branch')
        subject.should_receive(:git_call).with("checkout #{head_ref}")
        subject.checkout
      end

    end

  end

  describe '#approve' do

    it 'requires an valid ID' do
      subject.stub(:next_arg).and_return(nil)
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.approve
    end

    context 'when the request is valid' do

      before(:each) do
        subject.stub(:next_arg)
        github.stub(:request_exists?).and_return(request)
        github.stub(:source_repo).and_return('some_source')
      end

      it 'posts an approving comment in your name to the requests page' do
        comment = 'Reviewed and approved.'
        github.should_receive(:add_comment).
          with('some_source', request_number, 'Reviewed and approved.').
          and_return(:body => comment)
        subject.should_receive(:puts).with(/Successfully approved request./)
        subject.approve
      end

      it 'outputs any errors that might occur when trying to post a comment' do
        message = 'fail'
        github.should_receive(:add_comment).
          with('some_source', request_number, 'Reviewed and approved.').
          and_return(:body => nil, :message => message)
        subject.should_receive(:puts).with(message)
        subject.approve
      end

    end

  end

  describe '#merge' do

    it 'requires an valid ID' do
      subject.stub(:next_arg).and_return(nil)
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.merge
    end

    context 'when the request is valid' do

      before(:each) do
        subject.stub(:next_arg)
        github.stub(:request_exists?).and_return(request)
        github.stub(:source_repo)
      end

      it 'checks whether the source repository still exists' do
        request.head.stub(:repo).and_return(nil)
        subject.should_receive(:puts).with(/deleted the source repository./)
        subject.stub(:puts)
        subject.merge
      end

      it 'merges the request with your current branch' do
        msg = "Accept request ##{request_number} " +
            "and merge changes into \"/master\""
        subject.should_receive(:git_call).with("merge  -m '#{msg}' #{head_sha}")
        subject.merge
      end

    end

  end

  describe '#close' do

    it 'requires an valid ID' do
      subject.stub(:next_arg).and_return(nil)
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.close
    end

    it 'closes the request' do
      subject.stub(:next_arg)
      github.stub(:request_exists?).and_return(request)
      github.stub(:source_repo).and_return('some_source')
      github.should_receive(:close_issue).with('some_source', request_number)
      github.should_receive(:request_exists?).
        with('open', request_number).and_return(false)
      subject.should_receive(:puts).with(/Successfully closed request./)
      subject.close
    end

  end

  describe '#prepare' do

    context 'when on master branch' do

      before(:each) do
        local.stub(:source_branch).and_return('master')
        local.stub(:target_branch).and_return('master')
      end

      it 'creates a local branch with review prefix' do
        subject.stub(:next_arg).and_return(feature_name)
        subject.should_receive(:git_call).with("checkout -b #{branch_name}")
        subject.stub(:git_call)
        subject.prepare
      end

      it 'lets the user choose a name for the branch' do
        subject.stub(:next_arg).and_return(nil)
        subject.should_receive(:gets).and_return(feature_name)
        subject.should_receive(:git_call).with("checkout -b #{branch_name}")
        subject.stub(:git_call)
        subject.prepare
      end

      it 'creates a local branch when TARGET_BRANCH is defined' do
        subject.stub(:next_arg).and_return(feature_name)
        ENV.stub(:[]).with('TARGET_BRANCH').and_return(custom_target_name)
        subject.should_receive(:git_call).with("checkout -b #{branch_name}")
        subject.stub(:git_call)
        subject.prepare
      end

      it 'sanitizes provided branch names' do
        subject.stub(:next_arg).and_return('wild stuff?')
        subject.should_receive(:git_call).with(/wild_stuff/)
        subject.stub(:git_call)
        subject.prepare
      end

      #it 'moves uncommitted changes to the new branch' do
      #  subject.stub(:next_arg).and_return(feature_name)
      #  local.stub(:uncommited_changes?).and_return(true)
      #  local.stub(:source_branch).and_return(branch_name)
      #  subject.stub(:git_call)
      #  subject.should_receive(:git_call).with('stash')
      #  subject.prepare
      #end
      #
      #it 'moves unpushed commits to the new branch' do
      #  assume_change_branches :master => :feature
      #  assume_arguments feature_name
      #  assume_uncommitted_changes false
      #  subject.should_receive(:git_call).with(include 'reset --hard')
      #  subject.prepare
      #end

    end

  end

  #describe '#create' do
  #
  #  context 'when on feature branch' do
  #
  #    before(:each) do
  #      local.stub(:source_branch).and_return(feature_name)
  #      local.stub(:target_branch).and_return(feature_name)
  #    end
  #
  #  end
  #
  #  it 'warns the user about uncommitted changes' do
  #    assume_uncommitted_changes
  #    subject.should_receive(:puts).with(include 'uncommitted changes')
  #    subject.create
  #  end
  #
  #  it 'pushes the commits to a remote branch and creates a pull request' do
  #    assume_no_requests
  #    assume_on_feature_branch
  #    assume_uncommitted_changes false
  #    assume_local_commits
  #    assume_title_and_body_set
  #    assume_change_branches
  #    subject.should_receive(:git_call).with(
  #      "push --set-upstream origin #{branch_name}", false, true
  #    )
  #    subject.should_receive :update
  #    github.should_receive(:create_pull_request).with(
  #      source_repo, 'master', branch_name, title, body
  #    )
  #    subject.create
  #  end
  #
  #  it 'lets the user return to the branch she was working on before' do
  #    assume_no_requests
  #    assume_uncommitted_changes false
  #    assume_local_commits
  #    assume_title_and_body_set
  #    assume_create_pull_request
  #    assume_on_feature_branch
  #    subject.should_receive(:git_call).with('checkout master').ordered
  #    subject.should_receive(:git_call).with("checkout #{branch_name}").ordered
  #    subject.create
  #  end
  #
  #end

  describe '#clean' do

    before(:each) do
      subject.stub(:git_call).with('remote prune origin')
    end

    it 'requires either an ID or the additional parameter --all' do
      subject.instance_variable_set(:@args, [])
      subject.should_receive(:puts).with(/either an ID or "--all"/)
      subject.clean
    end

    it 'removes a single obsolete branch with review prefix' do
      subject.instance_variable_set(:@args, [request_number])
      local.should_receive(:clean_single).with(request_number)
      subject.clean
    end

    it 'removes all obsolete branches with review prefix' do
      subject.instance_variable_set(:@args, ['--all'])
      local.should_receive(:clean_all)
      subject.clean
    end

    it 'deletes a branch with unmerged changes with --force option' do
      subject.instance_variable_set(:@args, [request_number, '--force'])
      local.should_receive(:clean_single).with(request_number, force = true)
      subject.clean
    end

  end

end
