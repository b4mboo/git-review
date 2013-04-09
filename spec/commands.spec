require 'spec_helper'

describe 'git review <COMMAND>' do

  include_context :request


  describe 'help' do

    it 'shows the help page' do
      subject.should_receive(:puts).with(
        include('Usage: git review <command>')
      )
      subject.help
    end

  end


  describe 'list' do

    it 'shows all open pull requests' do
      assume :@current_requests, [request, request]
      assume_merged false
      request.should_receive(:title).twice.and_return('first', 'second')
      subject.should_receive(:puts).with(include 'Pending requests')
      subject.should_not_receive(:puts).with(include 'No pending requests')
      subject.should_receive(:puts).with(include 'first').ordered
      subject.should_receive(:puts).with(include 'second').ordered
      subject.list
    end

    it 'allows for an optional argument --reverse to sort the output' do
      assume :@current_requests, [request, request]
      assume :@args, ['--reverse']
      assume_merged false
      request.should_receive(:title).twice.and_return('first', 'second')
      subject.should_receive(:puts).with(include 'Pending requests')
      subject.should_not_receive(:puts).with(include 'No pending requests')
      subject.should_receive(:puts).with(include 'second').ordered
      subject.should_receive(:puts).with(include 'first').ordered
      subject.list
    end

    it 'respects local changes when determining whether requests are merged' do
      assume :@current_requests, [request]
      assume_merged true
      subject.should_receive(:puts).with(include 'No pending requests')
      subject.should_not_receive(:puts).with(include 'Pending requests')
      subject.list
    end

    it 'knows when there are no open pull requests' do
      assume :@current_requests, []
      subject.instance_variable_get(:@current_requests).should be_empty
      subject.should_receive(:puts).with(include 'No pending requests')
      subject.should_not_receive(:puts).with(include 'Pending requests')
      subject.list
    end

  end


  describe 'show' do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.show
    end

    it 'shows a single pull request' do
      assume_a_valid_request_id
      subject.should_receive(:puts).with(title)
      # Ensure the request's stats are shown.
      subject.should_receive(:git_call).with(
        "diff --color=always --stat HEAD...#{head_sha}"
      )
      subject.show
    end

    it 'shows a pull request\'s diff if a parameter \'--full\' is appended' do
      assume_a_valid_request_id
      assume_added_to :@args, '--full'
      subject.should_receive(:puts).with(title)
      # Ensure the request's full diff is shown.
      subject.should_receive(:git_call).with(
        "diff --color=always HEAD...#{head_sha}"
      )
      subject.show
    end

  end


  describe 'browse' do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.browse
    end

    it 'opens the pull request\'s page on GitHub in a browser' do
      assume_a_valid_request_id
      Launchy.should_receive(:open).with(request_url)
      subject.browse
    end

  end


  describe 'checkout' do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.checkout
    end

    it 'creates a headless state in the local repo with the request\'s code' do
      assume_a_valid_request_id
      subject.should_receive(:git_call).with("checkout origin/#{head_ref}")
      subject.checkout
    end

    it 'creates a local branch if the optional param --branch is appended' do
      assume_a_valid_request_id
      assume_added_to :@args, '--branch'
      subject.should_receive(:git_call).with("checkout #{head_ref}")
      subject.checkout
    end

  end


  describe 'approve' do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.approve
    end

    it 'posts an approving comment in your name to the request\'s page' do
      assume_a_valid_request_id
      comment = 'Reviewed and approved.'
      github.should_receive(:add_comment).
        with(source_repo, request_id, comment).
        and_return(:body => comment)
      subject.should_receive(:puts).with(include 'Successfully')
      subject.approve
    end

    it 'outputs any errors that might occur when trying to post a comment' do
      assume_a_valid_request_id
      message = 'fail'
      github.should_receive(:add_comment).
        with(source_repo, request_id, 'Reviewed and approved.').
        and_return(:body => nil, :message => message)
      subject.should_receive(:puts).with(include message)
      subject.approve
    end

  end


  describe 'merge' do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.merge
    end

    it 'checks whether the source repository still exists' do
      assume_a_valid_request_id
      request.head.repo = nil
      subject.should_receive(:puts).with(include 'deleted the source repo')
      subject.merge
    end

    it 'merges the request with your current branch' do
      assume_a_valid_request_id
      msg = "Accept request ##{request_id} and merge changes into \"//master\""
      subject.should_receive(:git_call).with("merge  -m '#{msg}' #{head_sha}")
      subject.merge
    end

  end


  describe 'close' do

    it 'requires an ID as additional parameter' do
      subject.should_receive(:puts).with('Please specify a valid ID.')
      subject.close
    end

    it 'closes the request' do
      assume_a_valid_request_id
      github.should_receive(:close_issue).with(source_repo, request_id)
      github.should_receive(:pull_requests)
      .with(source_repo, 'open').and_return([])
      subject.close
    end

  end


  describe 'prepare' do

    it 'creates a local branch with review prefix' do
      assume_on_master
      assume :@args, [feature_name]
      subject.should_receive(:git_call).with("checkout -b #{branch_name}")
      subject.prepare
    end

    it 'lets the user choose a name for the branch' do
      assume_on_master
      subject.should_receive(:gets).and_return(feature_name)
      subject.should_receive(:git_call).with("checkout -b #{branch_name}")
      subject.prepare
    end

    it 'sanitizes provided branch names' do
      not_sanitized = 'wild stuff?'
      sanitized = 'wild_stuff'
      assume_on_master
      assume :@args, [not_sanitized]
      subject.should_receive(:git_call).with(include sanitized)
      subject.prepare
    end

    it 'moves uncommitted changes to the new branch' do
      assume_change_branches :master => :feature
      assume :@args, [feature_name]
      assume_uncommitted_changes true
      subject.stub(:git_call).with(include 'reset --hard')
      subject.should_receive(:git_call).with('stash')
      subject.should_receive(:git_call).with('stash pop')
      subject.prepare
    end

    it 'moves unpushed commits to the new branch' do
      assume_change_branches :master => :feature
      assume :@args, [feature_name]
      assume_uncommitted_changes false
      subject.should_receive(:git_call).with(include 'reset --hard')
      subject.prepare
    end

  end


  describe 'create' do

    it 'calls \'prepare\' if it is called from master' do
      assume_on_master
      assume_uncommitted_changes false
      assume_local_commits false
      subject.should_receive(:prepare)
      subject.create
    end

    it 'warns the user about uncommitted changes' do
      assume_on_feature_branch
      assume_uncommitted_changes true
      subject.should_receive(:puts).with(include 'uncommitted changes')
      subject.create
    end

    it 'pushes the commits to a remote branch and creates a pull request' do
      assume_no_open_requests
      assume_on_feature_branch
      assume_uncommitted_changes false
      assume_local_commits true
      assume_title_and_body_set
      assume_change_branches
      subject.should_receive(:git_call).with(
        "push --set-upstream origin #{branch_name}", false, true
      )
      subject.should_receive :update
      github.should_receive(:create_pull_request).with(
        source_repo, 'master', branch_name, title, body
      )
      subject.create
    end

    it 'lets the user return to the branch she was working on before' do
      assume_no_open_requests
      assume_uncommitted_changes false
      assume_local_commits true
      assume_title_and_body_set
      assume_create_pull_request
      assume_on_feature_branch
      subject.should_receive(:git_call).with('checkout master').ordered
      subject.should_receive(:git_call).with("checkout #{branch_name}").ordered
      subject.create
    end

  end


  describe 'clean' do

    before :each do
      assume_pruning
    end

    it 'requires either an ID or the additional parameter --all' do
      subject.should_receive(:puts).with(
        include('either an ID or "--all"')
      )
      subject.clean
    end

    it 'removes a single obsolete branch with review prefix' do
      assume :@args, [request_id]
      subject.should_receive(:clean_single)
      subject.clean
    end

    it 'removes all obsolete branches with review prefix' do
      assume :@args, ['--all']
      subject.should_receive(:clean_all)
      subject.clean
    end

    it 'needs an option \'--force\' to delete a branch with unmerged changes' do
      assume :@args, [request_id, '--force']
      subject.should_receive(:clean_single).with(force = true)
      subject.clean
    end

  end

end
