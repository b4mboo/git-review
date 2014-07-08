module GitReview

  module Provider

    class Bitbucket < Base

      include ::GitReview::Helpers

      attr_reader :bitbucket

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
