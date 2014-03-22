module GitReview

  # The local repository is where the git-review command is being called
  # by default. It is (supposedly) able to handle systems other than Github.
  # TODO: remove Github-dependency
  class Local

    include ::GitReview::Helpers

    attr_accessor :config

    # acts like a singleton class but it's actually not
    # use ::GitReview::Local.instance everywhere except in tests
    def self.instance
      @instance ||= new
    end

    def initialize
      # find root git directory if currently in subdirectory
      if git_call('rev-parse --show-toplevel').strip.empty?
        raise ::GitReview::InvalidGitRepositoryError
      else
        load_config
      end
    end

    # List all available remotes.
    def remotes
      git_call('remote').split("\n")
    end

    # Determine whether a remote with a given name exists?
    def remote_exists?(name)
      remotes.include? name
    end

    # Create a Hash with all remotes as keys and their urls as values.
    def remotes_with_urls
      result = {}
      git_call('remote -vv').split("\n").each do |line|
        entries = line.split("\t")
        remote = entries.first
        target_entry = entries.last.split(' ')
        direction = target_entry.last[1..-2].to_sym
        target_url = target_entry.first
        result[remote] ||= {}
        result[remote][direction] = target_url
      end
      result
    end

    # Collect all remotes for a given url.
    def remotes_for_url(remote_url)
      result = remotes_with_urls.collect do |remote, urls|
        remote if urls.values.all? { |url| url == remote_url }
      end
      result.compact
    end

    # Find or create the correct remote for a fork with a given owner name.
    def remote_for_request(request)
      repo_owner = request.head.repo.owner.login
      remote_url = server.remote_url_for(repo_owner)
      remotes = remotes_for_url(remote_url)
      if remotes.empty?
        remote = "review_#{repo_owner}"
        git_call("remote add #{remote} #{remote_url}", debug_mode, true)
      else
        remote = remotes.first
      end
      remote
    end

    # Remove obsolete remotes with review prefix.
    def clean_remotes
      protected_remotes = remotes_for_branches
      remotes.each do |remote|
        # Only remove review remotes that aren't referenced by current branches.
        if remote.index('review_') == 0 && !protected_remotes.include?(remote)
          git_call "remote remove #{remote}"
        end
      end
    end

    # Prune all configured remotes.
    def prune_remotes
      remotes.each { |remote| git_call "remote prune #{remote}" }
    end

    # Find all remotes which are currently referenced by local branches.
    def remotes_for_branches
      remotes = git_call('branch -lvv').gsub('* ', '').split("\n").map do |line|
        line.split(' ')[2][1..-2].split('/').first
      end
      remotes.uniq
    end

    # Finds the correct remote for a given branch name.
    def remote_for_branch(branch_name)
      remote = git_call("for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD)")
      return nil if remote.strip.empty? # no remote tracking branch
      remote.split("\n").each do |line|
        match = line.match(%r((.*)\/(.*)))
        return line.split('/').first if match
      end
    end

    # @return [Array<String>] all existing branches
    def all_branches
      git_call('branch -a').gsub('* ', '').split("\n").collect { |s| s.strip }
    end

    # @return [Array<String>] all open requests' branches shouldn't be deleted
    def protected_branches
      server.current_requests.collect { |r| r.head.ref }
    end

    # @return [Array<String>] all review branches with 'review_' prefix
    def review_branches
      all_branches.collect { |entry|
        # only use uniq branch names (no matter if local or remote)
        branch_name = entry.split('/').last
        branch_name if branch_name.index('review_') == 0
      }.compact.uniq
    end

    # clean a single request's obsolete branch
    def clean_single(number, force = false)
      request = server.pull_request(source_repo, number)
      if request && request.state == 'closed'
        # ensure there are no unmerged commits or '--force' flag has been set
        branch_name = request.head.ref
        if unmerged_commits?(branch_name) && !force
          puts "Won't delete branches that contain unmerged commits."
          puts "Use '--force' to override."
        else
          delete_branch(branch_name)
        end
      end
    rescue Octokit::NotFound
      false
    end

    # clean all obsolete branches
    def clean_all
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

    # @return [Boolean] whether there are local changes not committed
    def uncommitted_changes?
      !git_call('diff HEAD').empty?
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

    # @return [Boolean] whether there are commits not in target branch yet
    def new_commits?(upstream = false)
      # Check if an upstream remote exists and create it if necessary.
      remote_url = server.remote_url_for(*target_repo(upstream).split('/'))
      remote = remotes_for_url(remote_url).first
      unless remote
        remote = 'upstream'
        git_call "remote add #{remote} #{remote_url}"
      end
      git_call "fetch #{remote}"
      target = upstream ? "#{remote}/#{target_branch}" : target_branch
      not git_call("cherry #{target}").empty?
    end

    # @return [Boolean] whether a specified commit has already been merged.
    def merged?(sha)
      branches = git_call("branch --contains #{sha} 2>&1").split("\n").
          collect { |b| b.delete('*').strip }
      branches.include?(target_branch)
    end

    # @return [String] the source repo
    def source_repo
      server.source_repo
    end

    # @return [String] the current source branch
    def source_branch
      git_call('branch').chomp.match(/\*(.*)/)[0][2..-1]
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

    # if to send a pull request to upstream repo, get the parent as target
    # @return [String] the name of the target repo
    def target_repo(upstream = false)
      # TODO: Manually override this and set arbitrary repositories
      if upstream
        server.repository(source_repo).parent.full_name
      else
        source_repo
      end
    end

    # @return [String] combine target repo and branch
    def target
      "#{target_repo}/#{target_branch}"
    end

    # @return [String] the head string used for pull requests
    def head
      # in the form of 'user:branch'
      "#{source_repo.split('/').first}:#{source_branch}"
    end

    # @return [Boolean] whether already on a feature branch
    def on_feature_branch?
      # If current and target are the same, we are not on a feature branch.
      # If they are different, but we are on master, we should still to switch
      # to a separate branch (since master makes for a poor feature branch).
      source_branch != target_branch && source_branch != 'master'
    end

    # Remove all non word characters and turn them into underscores.
    def sanitize_branch_name(name)
      name.gsub(/\W+/, '_').downcase
    end

    def load_config
      @config = {}
      config_list.split("\n").each do |line|
        key, value = line.split(/=/, 2)
        if @config[key] && @config[key] != value
          @config[key] = [@config[key]].flatten << value
        else
          @config[key] = value
        end
      end
      @config
    end

    def config_list
      git_call('config --list', false)
    end

    def server
      @server ||= ::GitReview::Server.instance
    end

    # @return [Array(String, String)] the title and the body of pull request
    def create_title_and_body(target_branch)
      login = server.login
      commits = git_call("log --format='%H' HEAD...#{target_branch}").
        lines.count
      puts "Commits: #{commits}"
      if commits == 1
        # we can create a really specific title and body
        title = git_call("log --format='%s' HEAD...#{target_branch}").chomp
        body  = git_call("log --format='%b' HEAD...#{target_branch}").chomp
      else
        title = "[Review] Request from '#{login}' @ '#{source}'"
        body  = "Please review the following changes:\n"
        body += git_call("log --oneline HEAD...#{target_branch}").
          lines.map{|l| "  * #{l.chomp}"}.join("\n")
      end
      edit_title_and_body(title, body)
    end

    # TODO: refactor
    def edit_title_and_body(title, body)
      tmpfile = Tempfile.new('git-review')
      tmpfile.write(title + "\n\n" + body)
      tmpfile.flush
      editor = ENV['TERM_EDITOR'] || ENV['EDITOR']
      unless editor
        warn 'Please set $EDITOR or $TERM_EDITOR in your .bash_profile.'
      end

      system("#{editor || 'open'} #{tmpfile.path}")

      tmpfile.rewind
      lines = tmpfile.read.lines.to_a
      #puts lines.inspect
      title = lines.shift.chomp
      lines.shift if lines[0].chomp.empty?
      body = lines.join
      tmpfile.unlink
      [title, body]
    end

  end

end
