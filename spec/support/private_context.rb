unless RSpec.world.shared_example_groups[:private]

  shared_context :private do

    # Allow to access private methods directly to test them independently.
    class GitReview
      meths = new.private_methods - Object.new.private_methods
      public *meths.collect(&:to_sym)
    end

  end

end
