module Accessible

  # Setup simple exit criteria for recursion.
  def accessible?
    true
  end

  # Allow to set instance variables on initialization.
  def initialize(attributes_hash = {})
    self.update_attributes attributes_hash
  end

  # Provide access to instance variables like a hash with indifferent access.
  def [](key)
    self.instance_variable_get "@#{key}".to_sym
  end

  # Provide access to instance variables like a hash with indifferent access.
  def []=(key, value)
    self.instance_variable_set "@#{key}".to_sym, value
  end

  # Allow to set all attributes by assigning a hash.
  def update_attributes(attributes_hash)
    attributes_hash.each do |key, value|
      attribute = self[key]
      if attribute.respond_to? :accessible?
        attribute.update_attributes(value)
      else
        self[key] = value
      end
    end
  end

end
