class Request

  include Accessible

  attr_accessor :number,
                :head,
                :title,
                :body,
                :state,
                :html_url,
                :updated_at,
                :comments,
                :review_comments

  # Allow to set instance variables on initialization.
  def initialize(attributes_hash = {})
    self.head = Commit.new
    super attributes_hash
  end

end
