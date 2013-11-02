module GitReview

  module Helpers

    private

    # ask for branch name if not provided
    # @return [String] sanitized branch name
    def get_branch_name
      puts 'Please provide a name for the branch:'
      local.sanitize_branch_name gets.chomp
    end

    # @return [String] the complete feature branch name
    def create_feature_name(new_branch)
      "review_#{Time.now.strftime("%y%m%d")}_#{new_branch}"
    end

    # Move uncommitted changes from original_branch to a feature_branch.
    # @return [String] the new local branch uncommitted changes are moved to
    def move_local_changes(original_branch, feature_name)
      feature_branch = create_feature_name(feature_name)
      # By checking out the feature branch, the commits on the original branch
      # are copied over. That way we only need to remove pending (local) commits
      # from the original branch.
      git_call "checkout -b #{feature_branch}"
      if local.source_branch == feature_branch
        # Save any uncommitted changes, to be able to reapply them later.
        save_uncommitted_changes = local.uncommitted_changes?
        git_call('stash') if save_uncommitted_changes
        # Go back to original branch and get rid of pending (local) commits.
        git_call("checkout #{original_branch}")
        remote = local.remote_for_branch(original_branch)
        remote += '/' if remote
        git_call("reset --hard #{remote}#{original_branch}")
        git_call("checkout #{feature_branch}")
        git_call('stash pop') if save_uncommitted_changes
        feature_branch
      end
    end

    def server
      @server ||= ::GitReview::Server.instance
    end

    def local
      @local ||= ::GitReview::Local.instance
    end

    # System call to 'git'
    def git_call(command, verbose = debug_mode, enforce_success = false)
      if verbose
        puts
        puts "  git #{command}"
        puts
      end

      output = `git #{command}`
      puts output if verbose and not output.empty?

      if enforce_success and not command_successful?
        puts output unless output.empty?
        raise ::GitReview::UnprocessableState
      end

      output
    end

    # @return [Boolean] Whether the last issued system call was successful
    def command_successful?
      $?.exitstatus == 0
    end

    # @return [Boolean] Whether we are running in debugging moder or not
    def debug_mode
      ::GitReview::Settings.instance.review_mode == 'debug'
    end

  end

end
