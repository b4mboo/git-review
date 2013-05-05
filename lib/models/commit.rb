class Commit

  include Accessible
  include Deserializable
  extend Nestable

  nests :user => User,
        :repo => Repository

  attr_accessor :sha,
                :ref,
                :label

  def to_s
    @sha
  end

end
