module GitReview

  module Deserializable

    def deserializable?
      true
    end

    def update_from_mash(mash)
      # Recursively updates an instance's attributes from a Mash object.
      self.attributes.each do |attribute|
        unless mash.nil?
          if self.send(attribute).respond_to?(:deserializable?) &&
              self.send(attribute).deserializable?
            self.send(attribute).update_from_mash(mash[attribute])
          else
            self.instance_variable_set("@#{attribute}", mash[attribute])
            # puts "set #{mash[attribute]} for #{attribute} in #{self.class}."
          end
        end
      end
      self
    end

  end

end