class User

  include Accessible
  include Deserializable

  attr_accessor :login

  def to_s
    @login
  end

end
