unless RSpec.world.shared_example_groups[:private]

  shared_context :private do

    # Allow to access private methods directly to test them independently.
    GitReview.define_method :method_missing do |name, *arguments|
      send name, *arguments
    end

  end

end
