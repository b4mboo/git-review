require 'json'
require 'launchy'
require 'octokit'

class GitReview

  REVIEW_CACHE_FILE = '.git/review_cache.json'

  ## COMMANDS ##

  # Default command to show a quick reference of available commands.
  def help
    puts 'Usage: git review <command>'
    puts 'Manage review workflow for projects hosted on GitHub (using pull requests).'
    puts ''
    puts 'Available commands:'
    puts '   list [--reverse]          List all open requests.'
    puts '   show <number> [--full]    Show details of a single request.'
    puts '   browse <number>           Open a browser window and review a specified request.'
    puts '   create                    Create a new request.'
    puts '   merge <number>            Sign off a specified request by merging it into master.'
  end

  # List all open requests.
  def list
    puts "Open Pull Requests for #{@user}/#{@repo}"
    option = @args.shift
    open_requests = get_pull_info
    open_requests.reverse! if option == '--reverse'
    count = 0
    open_requests.each do |pull|
      line = []
      line << l(pull['number'], 4)
      line << l(Date.parse(pull['created_at']).strftime("%m/%d"), 5)
      line << l(pull['comments'], 2)
      line << l(pull['title'], 35)
      line << l(pull['head']['label'], 20)
      sha = pull['head']['sha']
      if not_merged?(sha)
        puts line.join ' '
        count += 1
      end
    end
    if count == 0
      puts ' -- no open pull requests --'
    end
  end

  # Show details of a single request.
  def show
    return unless review_exists?
    option = @args.shift
    puts "Number   : #{@review['number']}"
    puts "Label    : #{@review['head']['label']}"
    puts "Created  : #{@review['created_at']}"
    puts "Votes    : #{@review['votes']}"
    puts "Comments : #{@review['comments']}"
    puts
    puts "Title    : #{@review['title']}"
    puts "Body     :"
    puts
    puts @review['body']
    puts
    puts '------------'
    puts
    if option == '--full'
      exec "git diff --color=always HEAD...#{@review['head']['sha']}"
    else
      puts "cmd: git diff HEAD...#{@review['head']['sha']}"
      puts git("diff --stat --color=always HEAD...#{@review['head']['sha']}")
    end
  end

  # Open a browser window and review a specified request.
  def browse
    Launchy.open(@review['html_url']) if review_exists?
  end

  # Create a new request.
  def create
    repo = "#{@user}/#{@repo}"
    to_branch = 'master'
    from_branch = get_from_branch_title
    # TODO: Insert user- and repository-name into title.
    title = 'my title'
    # TODO: Insert commit messages into body (since this will be displayed inside the mail that is sent out).
    body = 'my body'
    Octokit.create_pull_request(repo, to_branch, from_branch, title, body)
    # TODO: Show success or failure message.
    # TODO: Switch branch back to master.
  end

  # Sign off a specified request by merging it into master.
  def merge
    return unless review_exists?
    option = @args.shift
    if @review['head']['repository']
      o = @review['head']['repository']['owner']
      r = @review['head']['repository']['name']
    else # they deleted the source repo
      o = @review['head']['user']['login']
      purl = @review['patch_url']
      puts "Sorry, #{o} deleted the source repository, git-review doesn't support this."
      puts "You can manually patch your repo by running:"
      puts
      puts "  curl #{purl} | git am"
      puts
      puts "Tell the contributor not to do this."
      return false
    end
    s = @review['head']['sha']
    message = "Merge pull request ##{@review['number']} from #{o}/#{r}\n\n---\n\n"
    message += @review['body'].gsub("'", '')
    if option == '--log'
      message += "\n\n---\n\nMerge Log:\n"
      puts cmd = "git merge --no-ff --log -m '#{message}' #{s}"
    else
      puts cmd = "git merge --no-ff -m '#{message}' #{s}"
    end
    exec(cmd)
  end

  # Start a console session (used for debugging).
  def console
    puts 'Entering debug console.'
    require 'ruby-debug'
    Debugger.start
    debugger
    puts 'Leaving debug console.'
  end

  private

  # Setup variables and call actual commands.
  def initialize(args)
    command = args.shift
    @user, @repo = repo_info
    @args = args
    configure
    if command && self.respond_to?(command)
      update
      self.send command
    else
      unless command.blank? or %w(-h --help).include?(command)
        puts "git-review: '#{command}' is not a valid command.\n\n"
      end
      help
    end
  end

  # Get latest changes from GitHub.
  def update
    cache_pull_info
    fetch_stale_forks
  end

  # Check existence of specified review and assign @review.
  def review_exists?
    review_id = @args.shift.to_i
    @review = get_pull_info.find{ |review| review['number'] == review_id}
    puts "Review '#{review_id}' does not exist." unless @review
    not @review.nil?
  end

  # System call to 'git'.
  def git(command, chomp=true)
    s = `git #{command}`
    s.chomp! if chomp
    s
  end

  def get_from_branch_title
    git('branch', false).match(/\*(.*)/)[0][2..-1]
  end

  def fetch_stale_forks
    pulls = get_pull_info
    repos = {}
    pulls.each do |pull|
      next if pull['head']['repository'].nil? # Fork has been deleted
      o = pull['head']['repository']['owner']
      r = pull['head']['repository']['name']
      s = pull['head']['sha']
      if !has_sha(s)
        repo = "#{o}/#{r}"
        repos[repo] = true
      end
    end
    if github_credentials_provided?
      endpoint = "git@github.com:"
    else
      endpoint = github_endpoint + "/"
    end
    repos.each do |repo, bool|
      puts "fetching #{repo}"
      git("fetch #{endpoint}#{repo}.git +refs/heads/*:refs/pr/#{repo}/*")
    end
  end

  def has_sha(sha)
    git("show #{sha} 2>&1")
    $?.exitstatus == 0
  end

  def not_merged?(sha)
    commits = git("rev-list #{sha} ^HEAD 2>&1")
    commits.split("\n").size > 0
  end

  # DISPLAY HELPER FUNCTIONS #

  def l(info, size)
    clean(info)[0, size].ljust(size)
  end

  def r(info, size)
    clean(info)[0, size].rjust(size)
  end

  def clean(info)
    info.to_s.gsub("\n", ' ')
  end

  # PRIVATE REPOSITORIES ACCESS

  def configure
    Octokit.configure do |config|
      config.login = github_login
      config.token = github_token
      config.endpoint = github_endpoint
    end
  end

  def github_login
    git("config --get-all github.user")
  end

  def github_token
    git("config --get-all github.token")
  end

  def github_endpoint
    host = git("config --get-all github.host")
    if host.size > 0
      host
    else
      'https://github.com'
    end
  end

  # API/DATA HELPER FUNCTIONS #

  def github_credentials_provided?
    if github_token.empty? && github_login.empty?
      return false
    end
    true
  end

  def get_pull_info
    get_data(REVIEW_CACHE_FILE)['review']
  end

  def get_data(file)
    JSON.parse(File.read(file))
  end

  def cache_pull_info
    response = Octokit.pull_requests("#{@user}/#{@repo}")
    save_data({'review' => response}, REVIEW_CACHE_FILE)
  end

  def save_data(data, file)
    File.open(file, "w+") do |f|
      f.puts data.to_json
    end
  end

  def github_insteadof_matching(c, u)
    first = c.collect {|k,v| [v, /url\.(.*github\.com.*)\.insteadof/.match(k)]}.
              find {|v,m| u.index(v) and m != nil}
    if first
      return first[0], first[1][1]
    end
    return nil, nil
  end

  def github_user_and_proj(u)
    # Trouble getting optional ".git" at end to work, so put that logic below
    m = /github\.com.(.*?)\/(.*)/.match(u)
    if m
      return m[1], m[2].sub(/\.git\Z/, "")
    end
    return nil, nil
  end

  def repo_info
    c = {}
    config = git('config --list')
    config.split("\n").each do |line|
      k, v = line.split('=')
      c[k] = v
    end
    u = c['remote.origin.url']

    user, proj = github_user_and_proj(u)
    if !(user and proj)
      short, base = github_insteadof_matching(c, u)
      if short and base
        u = u.sub(short, base)
        user, proj = github_user_and_proj(u)
      end
    end
    [user, proj]
  end

end
