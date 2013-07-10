require 'grit'
require 'singleton'

module GitReview

  # The local repository is where the git-review command is being called
  # by default. It is (supposedly) not specific to Github.
  # TODO: remove Github-dependency
  class Local

    include Singleton
    include Internals

    attr_accessor :config

    def initialize(path='.')
      repo = Grit::Repo.new(path)
      @config = repo.config
    rescue
      raise ::GitReview::Errors::InvalidGitRepositoryError
    end

    # @return [Array<String>] all existing branches
    def all_branches
      git_call('branch -a').split("\n").collect { |s| s.strip }
    end

    # @return [Array<String>] all open requests' branches shouldn't be deleted
    def protected_branches
      ::GitReview::Github.instance.current_requests.collect { |r| r.head.ref }
    end

    # @return [Array<String>] all review branches with 'review_' prefix
    def review_branches
      all_branches.collect { |branch|
        # only use uniq branch names (no matter if local or remote)
        branch.split('/').last if branch.include?('review_')
      }.compact.uniq
    end

    # clean a single request's obsolete branch
    def clean_single(request_id, force=false)
      request = ::GitReview::Github.instance.get_request('closed', request_id)
      if request
        # ensure there are no unmerged commits or '--force' flag has been set
        branch_name = request.head.ref
        if unmerged_commits?(branch_name) && !force
          puts "Won't delete branches that contain unmerged commits."
          puts "Use '--force' to override."
        else
          delete_branch(branch_name)
        end
      end
    end

    # clean all obsolete branches
    def clean_all
      ::GitReview::Github.instance.update
      (review_branches - protected_branches).each do |branch_name|
        # only clean up obsolete branches.
        delete_branch(branch_name) unless unmerged_commits?(branch_name, false)
      end
    end

    # delete local and remote branches that match a given name
    # @param branch_name [String] name of the branch to delete
    def delete_branch(branch_name)
      delete_local_branch(branch_name)
      delete_remote_branch(branch_name)
    end

    # delete local branch if it exists.
    # @param (see #delete_branch)
    def delete_local_branch(branch_name)
      if branch_exists?(:local, branch_name)
        git_call("branch -D #{branch_name}", true)
      end
    end

    # delete remote branch if it exists.
    # @param (see #delete_branch)
    def delete_remote_branch(branch_name)
      if branch_exists?(:remote, branch_name)
        git_call("push origin :#{branch_name}", true)
      end
    end

    # @param location [Symbol] location of the branch, `:remote` or `:local`
    # @param branch_name [String] name of the branch
    # @return [Boolean] whether a branch exists in a specified location
    def branch_exists?(location, branch_name)
      return false unless [:remote, :local].include?(location)
      prefix = location == :remote ? 'remotes/origin/' : ''
      all_branches.include?(prefix + branch_name)
    end

    # @param branch_name [String] name of the branch
    # @param verbose [Boolean] if verbose output
    # @return [Boolean] whether there are unmerged commits on the local or
    #   remote branch.
    def unmerged_commits?(branch_name, verbose=true)
      locations = []
      locations << '' if branch_exists?(:local, branch_name)
      locations << 'origin/' if branch_exists?(:remote, branch_name)
      locations = locations.repeated_permutation(2).to_a
      if locations.empty?
        puts 'Nothing to do. All cleaned up already.' if verbose
        return false
      end
      # compare remote and local branch with remote and local master
      responses = locations.collect { |loc|
        git_call "cherry #{loc.first}#{target_branch} #{loc.last}#{branch_name}"
      }
      # select commits (= non empty, not just an error message and not only
      #   duplicate commits staring with '-').
      unmerged_commits = responses.reject { |response|
        response.empty? or response.include?('fatal: Unknown commit') or
            response.split("\n").reject { |x| x.index('-') == 0 }.empty?
      }
      # if the array ain't empty, we got unmerged commits
      if unmerged_commits.empty?
        false
      else
        puts "Unmerged commits on branch '#{branch_name}'."
        true
      end
    end

    # @return [Boolean] whether a specified commit has already been merged.
    def merged?(sha)
      not git_call("rev-list #{sha} ^HEAD 2>&1").split("\n").size > 0
    end

    # @return [String] the source repo
    def source_repo
      ::GitReview::Github.instance.source_repo
    end

    # @return [String] the current source branch
    def source_branch
      ::GitReview::Github.instance.source_branch
    end

    # @return [String] combine source repo and branch
    def source
      "#{source_repo}/#{source_branch}"
    end

    # @return [String] the name of the target branch
    def target_branch
      # TODO: Manually override this and set arbitrary branches
      ENV['TARGET_BRANCH'] || 'master'
    end

    # @return [String] the name of the target repo
    def target_repo
      # TODO: Manually override this and set arbitrary repositories
      source_repo
    end

    # @return [String] combine target repo and branch
    def target
      "#{target_repo}/#{target_branch}"
    end

    # @return [Boolean] whether already on a feature branch
    def on_feature_branch?
      # If current and target are the same, we are not on a feature branch.
      # If they are different, but we are on master, we should still to switch
      # to a separate branch (since master makes for a poor feature branch).
      source_branch != target_branch && source_branch != 'master'
    end

  end

end
