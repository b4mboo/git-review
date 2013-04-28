class Request

  include Accessible
  include Deserializable
  extend Nestable

  nests :head => Commit,
        :base => Commit,
        :user => User

  attr_accessor :number,
                :title,
                :body,
                :state,
                :html_url,
                :diff_url,
                :patch_url,
                :issue_url,
                :created_at,
                :updated_at,
                :comments,
                :review_comments

end
