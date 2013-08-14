require_relative '../spec_helper'
require_relative '../support/request_context'

describe 'Commands' do

  include_context 'request_context'

  subject { ::GitReview::Commands }
  let(:github) { ::GitReview::Github.any_instance }
  let(:local) { ::GitReview::Local.any_instance }

  before(:each) do
    github.stub(:configure_github_access).and_return('username')
  end

  describe '#help' do

    it 'shows the help page' do
      subject.should_receive(:puts).with(/Usage: git review <command>/)
      subject.help
    end

  end

  describe '#list' do

    before(:each) do
      local.stub(:source).and_return('some_source')
    end

    context 'when listing all unmerged pull requests' do

      let(:req1) { request.clone }
      let(:req2) { request.clone }

      before(:each) do
        req1.title, req2.title = 'first', 'second'
        github.stub(:current_requests_full).and_return([req1, req2])
        local.stub(:merged?).and_return(false)
      end

      it 'shows them' do
        subject.stub(:next_arg)
        subject.should_receive(:puts).with(/Pending requests for 'some_source'/)
        subject.should_not_receive(:puts).with(/No pending requests/)
        subject.should_receive(:print_request).with(req1).ordered
        subject.should_receive(:print_request).with(req2).ordered
        subject.list
      end

      it 'sorts the output with --reverse option' do
        subject.stub(:next_arg).and_return('--reverse')
        subject.stub(:puts)
        subject.should_receive(:print_request).with(req2).ordered
        subject.should_receive(:print_request).with(req1).ordered
        subject.list
      end

    end

    context 'when pull requests are already merged' do

      before(:each) do
        github.stub(:current_requests_full).and_return([request])
        local.stub(:merged?).and_return(true)
      end

      it 'does not list them' do
        subject.stub(:next_arg)
        subject.should_receive(:puts).
            with(/No pending requests for 'some_source'/)
        subject.should_not_receive(:print_request)
        subject.list
      end

    end

    it 'knows when there are no open pull requests' do
      github.stub(:current_requests_full).and_return([])
      subject.stub(:next_arg)
      subject.should_receive(:puts).
          with(/No pending requests for 'some_source'/)
      subject.should_not_receive(:print_request)
      subject.list
    end

  end

  describe '#show' do

    it 'requires an ID' do
      subject.stub(:next_arg).and_return(nil)
      expect { subject.show }.to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'requires a valid request number' do
      subject.stub(:next_arg).and_return(0)
      github.stub(:request_exists?).and_return(false)
      expect { subject.show }.to raise_error(::GitReview::InvalidRequestIDError)
    end

    context 'when the pull request number is valid' do

      before(:each) do
        subject.stub(:get_request_or_return).and_return(request)
        subject.stub(:puts)
      end

      it 'shows stats of the request' do
        subject.stub(:next_arg).and_return(nil)
        subject.should_receive(:git_call).
            with("diff --color=always --stat HEAD...#{head_sha}")
        subject.stub(:print_request_details)
        subject.stub(:print_request_discussions)
        subject.show
      end

      it 'shows full diff with --full option' do
        subject.stub(:next_arg).and_return('--full')
        subject.should_receive(:git_call).
            with("diff --color=always HEAD...#{head_sha}")
        subject.stub(:print_request_details)
        subject.stub(:print_request_discussions)
        subject.show
      end

    end

  end

  describe '#browse' do

    it 'requires an valid ID' do
      subject.stub(:next_arg).and_return(nil)
      expect { subject.browse }.
          to raise_error(::GitReview::InvalidRequestIDError)
    end

    it 'opens the pull request page on GitHub in a browser' do
      subject.stub(:get_request_or_return).and_return(request)
      Launchy.should_receive(:open).with(html_url)
      subject.browse
    end

  end

  describe '#checkout' do

    it 'requires an valid ID' do
      subject.stub(:next_arg).and_return(nil)
      expect { subject.checkout }.
          to raise_error(::GitReview::InvalidRequestIDError)
    end

    context 'when the request is valid' do

      before(:each) do
        subject.stub(:get_request_or_return).and_return(request)
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
      expect { subject.approve }.
          to raise_error(::GitReview::InvalidRequestIDError)
    end

    context 'when the request is valid' do

      before(:each) do
        subject.stub(:get_request_or_return).and_return(request)
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
      expect { subject.merge }.
          to raise_error(::GitReview::InvalidRequestIDError)
    end

    context 'when the request is valid' do

      before(:each) do
        subject.stub(:get_request_or_return).and_return(request)
        subject.stub(:next_arg)
        github.stub(:source_repo)
      end

      it 'does not proceed if source repo no longer exists' do
        request.head.stub(:repo).and_return(nil)
        subject.should_receive(:print_repo_deleted)
        subject.should_not_receive(:git_call)
        subject.merge
      end

      it 'merges the request with your current branch' do
        msg = "Accept request ##{request_number} " +
            "and merge changes into \"/master\""
        subject.should_receive(:git_call).with("merge  -m '#{msg}' #{head_sha}")
        subject.stub(:puts)
        subject.merge
      end

    end

  end

  describe '#close' do

    it 'requires an valid ID' do
      subject.stub(:next_arg).and_return(nil)
      expect { subject.close }.
          to raise_error(::GitReview::InvalidRequestIDError)
    end

    context 'when the request is valid' do

      before(:each) do
        subject.stub(:get_request_or_return).and_return(request)
        subject.stub(:next_arg)
        github.stub(:source_repo).and_return('some_source')
      end

      it 'closes the request' do
        github.should_receive(:close_issue).with('some_source', request_number)
        github.should_receive(:request_exists?).
            with('open', request_number).and_return(false)
        subject.should_receive(:puts).with(/Successfully closed request./)
        subject.close
      end

    end

  end

  describe '#prepare' do

    context 'when on master/target branch' do

      before(:each) do
        local.stub(:source_branch).and_return('master')
        local.stub(:target_branch).and_return('master')
        subject.stub(:puts)
        subject.stub(:git_call)
      end

      it 'creates a local branch with review prefix' do
        subject.stub(:next_arg).and_return(feature_name)
        subject.should_receive(:git_call).with("checkout -b #{branch_name}")
        subject.prepare
      end

      it 'lets the user choose a name for the branch' do
        subject.stub(:next_arg).and_return(nil)
        subject.should_receive(:gets).and_return(feature_name)
        subject.should_receive(:git_call).with("checkout -b #{branch_name}")
        subject.prepare
      end

      it 'creates a local branch when TARGET_BRANCH is defined' do
        subject.stub(:next_arg).and_return(feature_name)
        ENV.stub(:[]).with('TARGET_BRANCH').and_return(custom_target_name)
        subject.should_receive(:git_call).with("checkout -b #{branch_name}")
        subject.prepare
      end

      it 'sanitizes provided branch names' do
        subject.stub(:next_arg).and_return('wild stuff?')
        subject.should_receive(:git_call).
            with(/checkout -b review_\d+_wild_stuff/)
        subject.prepare
      end

      xit 'moves uncommitted changes to the new branch' do
        subject.stub(:get_branch_name).and_return(feature_name)
        local.stub(:source_branch).and_return(branch_name)
        local.stub(:uncommited_changes?).and_return(true)
        subject.should_receive(:git_call).with('stash')
        subject.should_receive(:git_call).with('reset --hard origin/master')
        subject.send(:move_uncommitted_changes, 'master')
      end

    end

  end

  describe '#create' do

    before(:each) do
      subject.stub(:prepare).and_return(['master', branch_name])
    end

    context 'when sending pull request to current repo' do

      before(:each) do
        subject.stub(:next_arg).and_return(nil)
        local.stub(:source_branch).and_return(branch_name)
        local.stub(:target_branch).and_return('master')
      end

      context 'when there are uncommitted changes' do

        before(:each) do
          subject.stub(:git_call).with('diff HEAD').and_return('some diffs')
        end

        it 'warns the user about uncommitted changes' do
          subject.stub(:puts)
          subject.should_receive(:puts).with(/uncommitted changes/)
          subject.create
        end

      end

      context 'when there are no uncommitted changes' do

        before(:each) do
          subject.stub(:git_call)
          subject.stub(:git_call).with('diff HEAD').and_return('')
          subject.stub(:git_call).with(/cherry/).and_return('some commits')
        end

        it 'pushes the commits to a remote branch and creates a pull request' do
          subject.should_receive(:git_call).with(
              "push --set-upstream origin #{branch_name}", false, true
          )
          subject.should_receive(:create_pull_request)
          subject.create
        end

        it 'lets the user return to the branch she was working on before' do
          subject.stub(:create_pull_request)
          subject.should_receive(:git_call).with("checkout master")
          subject.create
        end

      end

    end

    context 'when sending pull request to upstream repo' do



      let(:upstream) {
        Hashie::Mash.new(:parent => {:full_name => 'upstream'})
      }

      before(:each) do
        subject.stub(:next_arg).and_return('--upstream')
        github.github.stub(:login).and_return('user')
        local.stub(:source_branch).and_return(branch_name)
        local.stub(:target_branch).and_return('master')
        github.stub(:repository).and_return(upstream)
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

  describe '#clean' do

    before(:each) do
      subject.stub(:git_call).with('remote prune origin')
      allow_message_expectations_on_nil
    end

    it 'requires either an ID or the additional parameter --all' do
      subject.args.stub(:size).and_return(0)
      expect { subject.clean }.
          to raise_error(::GitReview::InvalidArgumentError)
    end

    it 'removes a single obsolete branch with review prefix' do
      subject.args.stub(:size).and_return(1)
      subject.stub(:next_arg).and_return(request_number)
      local.should_receive(:clean_single).with(request_number)
      subject.clean
    end

    it 'removes all obsolete branches with review prefix' do
      subject.args.stub(:size).and_return(1)
      subject.stub(:next_arg).and_return('--all')
      local.should_receive(:clean_all)
      subject.clean
    end

    it 'deletes a branch with unmerged changes with --force option' do
      subject.args.stub(:size).and_return(2)
      subject.stub(:next_arg).and_return(request_number, '--force')
      local.should_receive(:clean_single).with(request_number, force=true)
      subject.clean
    end

  end

end
