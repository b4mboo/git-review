class Request

  include Accessible
  extend Nestable

  nests :head => Commit

  attr_accessor :number,
                :title,
                :body,
                :state,
                :html_url,
                :patch_url,
                :updated_at,
                :comments,
                :review_comments

  def number_of_comments
    if comments.nil? or review_comments.nil?
      return "Bug"
      # Find a way to deal with this
      # with Octokit::Client::pull_request, comments and review_comments are set
      # but with Octokit::Client::pull_requests, it is not set
    end
    comments + review_comments
  end

end
