class Request

  include Accessible
  extend Nestable

  nests head: Commit

  attr_accessor :number,
                :title,
                :body,
                :state,
                :html_url,
                :patch_url,
                :updated_at,
                :comments,
                :review_comments

end
