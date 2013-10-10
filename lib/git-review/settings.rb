require 'fileutils'
require 'yaml'
require 'hashie'

module GitReview

  class Settings

    def self.instance
      @instance ||= new
    end

    def save!
      File.write(file, dumped)
    end

    def method_missing(method, *args)
      if args.empty?
        config.send(method)
      else
        config.send(method, args.shift)
      end
    end

    def respond_to?(method)
      config.respond_to?(method) || super
    end

    protected

    def config
      @config ||= Hashie::Mash.new loaded
    end

    def file
      @file ||= File.join(Dir.home, '.git_review.yml')
    end

    def loaded
      if File.exists? file
        YAML.load_file(file)
      else
        {}
      end
    end

    def dumped
      YAML.dump config.to_hash
    end

  end

end
