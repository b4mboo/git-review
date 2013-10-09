module GitReview

  module Provider

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

      def configure_access
      end

      def source_repo
      end

      def update
        git_call('fetch origin')
      end

    end

  end

end
