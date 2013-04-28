module Deserializable

  def deserializable?
    true
  end

  def update_from_mash(mash)
    self.attributes.each do |attribute|
      unless mash.nil?
        if self.send(attribute).respond_to? :deserializable?
          # Don't ever ever ever use mash.send(attribute),
          # otherwise your computer will recursively explode.
          # Mine did.
          self.send(attribute).update_from_mash(mash[attribute])
        else
          self.instance_variable_set("@#{attribute}", mash[attribute])
        end
      end
    end
    self
  end

end
