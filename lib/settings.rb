require 'fileutils'
require 'singleton'
require 'yaml'

class Settings
  include Singleton

  def initialize
    @config_file = File.join(
      Dir.home,
      '.git_review.yml'
    )

    @config = if File.exists?(@config_file)
      YAML.load_file(@config_file) || {}
    else
      {}
    end
  end

  def save!
    File.open(@config_file, 'w') do |file|
      file.write(YAML.dump(@config))
    end
  end

  def review_mode
    @config['review_mode']
  end

  def oauth_token
    @config['oauth_token']
  end

  def oauth_token=(token)
    @config['oauth_token'] = token
  end

  def username
    @config['username']
  end

  def username=(username)
    @config['username'] = username
  end

end
