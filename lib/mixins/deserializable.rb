module Deserializable

  def deserializable?
    true
  end

  def update_from_mash(mash)
    self.attributes.each do |attribute|
      if attribute.respond_to? :deserializable?
        self.send(attribute).update_from_mash(mash.send(attribute))
      else
        self.instance_variable_set("@#{attribute}", mash.send(attribute))
      end
    end
    self
  end

end
