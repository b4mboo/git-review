module GitReview

  class Bitbucket

    include ::GitReview::Internals

    attr_reader :bitbucket
    attr_accessor :source_repo

    # acts like a singleton class but it's actually not
    # use ::GitReview::Bitbucket.instance everywhere except in tests
    def self.instance
      @instance ||= new
    end

    def initialize
    end

  end

end
