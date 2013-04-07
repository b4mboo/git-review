class Commit

  include Accessible

  attr_accessor :sha,
                :ref,
                :label,
                :repo

end
