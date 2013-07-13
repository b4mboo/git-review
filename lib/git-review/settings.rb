require 'fileutils'
require 'singleton'
require 'yaml'

module GitReview

  class Settings

    include Singleton

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
    def method_missing(method, *args)
      # Determine whether to set or get an attribute.
      if method.to_s =~ /(.*)=$/
        @config[$1.to_sym] = args.shift
      else
        @config[method.to_sym]
      end
    end

  end

end
