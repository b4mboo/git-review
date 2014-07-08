# Base class from which all models inherit. This way we can be sure that all of
# them get the mixins and a reference to the server they are derived from.
class Base

  include Accessible
  extend Nestable

  attr_accessor :server

end
