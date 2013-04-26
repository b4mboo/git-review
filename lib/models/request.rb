class Request

  include Accessible
  extend Nestable

  attr_accessor :number,
                :head,
                :title,
                :body,
                :state,
                :html_url,
                :patch_url,
                :updated_at,
                :comments,
                :review_comments,
                :host # to retrieve new data

  def self.find_all(host, source_repo, state)
    host.pull_requests(source_repo, state).map do |request|
      r = Request.new request
      r.host = host
      r
    end
  end

  def self.find(host, source_repo, request_id)
    r = Request.new host.pull_request(source_repo, request_id)
    r.host = host
    r
  end

  def issue_comments
    if @issue_comments.nil?
      @issue_comments = @host.issue_comments(@base.repo.full_name, @number).map do |comment|
        Comment.new comment
      end
    end
    @issue_comments
  end

  def pull_comments
    if @pull_comments.nil?
      @pull_comments = @host.pull_comments(@base.repo.full_name, @number).map do |comment|
        Comment.new comment
      end
    end
    @pull_comments
  end

  def pull_commits
    if @pull_commits.nil?
      @pull_commits = @host.pull_commits(@base.repo.full_name, @number).map do |commit|
        c = Commit.new commit
        c.host = @host
        c.head_repo = @head.repo
        c
      end
    end
    @pull_commits
  end

  def number_of_comments
    # with Octokit::Client::pull_request, comments and review_comments are set
    # but with Octokit::Client::pull_requests, it is not set
    # This is the advantage of this method over
    #     issue comments.count + pull_comments.count
    # because if comments and review_comments already exist, we
    # avoid fetching all the comments
    if @comments.nil?
      @comments = issue_comments.count # Not `@issue_comments` because the
                                       # method reloads it if necessary
    end
    if @review_comments.nil?
      @review_comments = pull_comments.count
    end
    @comments + @review_comments
  end

end
