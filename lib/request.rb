class Request

  attr_accessor :number,
                :sha,
                :label,
                :title,
                :body,
                :state,
                :html_url,
                :updated_at,
                :comments,
                :review_comments

  # Allow to set instance variables on initialization.
  def initialize(attributes_hash = {})
    attributes_hash.each do |key, value|
      self[key] = value
    end
  end

  # Simplify request hashes by not nesting 'head', but instead holding all
  # attributes in one flat list. Just redirect to self, if someone wants to
  # access 'head'. Thus request.head.sha == request.sha.
  def head
    self
  end

  # Provide access to instance variables like a hash with indifferent access.
  def [](key)
    return self.head if key.to_sym == :head
    self.instance_variable_get "@#{key}".to_sym
  end

  # Provide access to instance variables like a hash with indifferent access.
  def []=(key, value)
    return self.head if key.to_sym == :head
    self.instance_variable_set "@#{key}".to_sym, value
  end

end
