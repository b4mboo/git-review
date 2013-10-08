module Nestable

  def nests(mapping)
    # Setup an accessor for all nested instances.
    attr_accessor *mapping.keys

    # Create a nested instance automatically on initialize.
    define_method(:initialize) do |arguments = nil|
      mapping.each do |attribute, klass|
        self.instance_variable_set "@#{attribute}".to_sym, klass.new
      end
      super arguments if arguments
    end
  end

end
