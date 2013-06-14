require 'fileutils'
require 'singleton'
require 'yaml'

module GitReview

  class Settings

    include Singleton

    attr_accessor :username, :oauth_token

    # Read settings from ~/.git_review.yml upon initialization.
    def initialize
      @config_file = File.join(Dir.home, '.git_review.yml')
      @config = YAML.load_file(@config_file) if File.exists?(@config_file)
      @config ||= {}
    end

    # Write settings back to file.
    def save!
      File.open(@config_file, 'w') do |file|
        file.write(YAML.dump(@config))
      end
    end

    # Allow to access config options.
    def method_missing(*args)
      name = args.shift.to_s
      # Determine whether to set or get an attribute.
      if name.end_with? '='
        @config[name[0..-2]] = args.shift
      else
        @config[name]
      end
    end

  end

end
