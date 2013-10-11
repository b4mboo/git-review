require 'net/http'
require 'net/https'
require 'yajl'
require 'io/console'
require 'stringio'
require 'socket'

module GitReview

  module Provider

    class Base

      include ::GitReview::Helpers

      attr_reader :client
      attr_accessor :source_repo

      def self.instance
        @instance ||= new
      end

      def initialize
        configure_access
      end

      def update
        git_call('fetch origin')
      end

      # @return [String] Source repo name
      def source_repo
        @source_repo ||= begin
          user, repo = repo_info_from_config
          "#{user}/#{repo}"
        end
      end

      # @return [Array(String, String)] User and repo name from git
      def repo_info_from_config
        url = local.config['remote.origin.url']
        raise ::GitReview::InvalidGitRepositoryError if url.nil?

        user, project = url_matching(url)

        unless user && project
          insteadof_url, true_url = insteadof_matching(local.config, url)

          if insteadof_url and true_url
            url = url.sub(insteadof_url, true_url)
            user, project = url_matching(url)
          end
        end

        [user, project]
      end

      # Ensure we find the right request
      def get_request_by_number(request_number)
        request_exists?(request_number) || (raise ::GitReview::InvalidRequestIDError)
      end

      def method_missing(method, *args)
        if client.respond_to?(method)
          client.send(method, *args)
        else
          super
        end
      end

      def respond_to?(method)
        client.respond_to?(method) || super
      end

      private

      def configure_oauth
        begin
          prepare_username_and_password
          prepare_description
          authorize
        rescue ::GitReview::AuthenticationError => e
          warn e.message
        rescue ::GitReview::UnprocessableState => e
          warn e.message
          exit 1
        end
      end

      def authorize
      end

      def prepare_username_and_password
      end

      def prepare_description(chosen_description=nil)
        if chosen_description
          @description = chosen_description
        else
          @description = "git-review - #{Socket.gethostname}"

          puts "Please enter a description to associate to this token."
          puts "It will make easier to find it inside of application page."
          puts "Press enter to accept the proposed description."

          print "Description [#{@description}]:"
          user_description = STDIN.gets.chomp

          @description = user_description.empty? ? @description : user_description
        end
      end

      def local
        @local ||= ::GitReview::Local.instance
      end

      def settings
        @settings ||= ::GitReview::Settings.instance
      end

    end

  end

end
