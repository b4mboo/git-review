require 'net/http'
require 'net/https'
# Used to handle json data
require 'yajl'
# Required to hide password
require 'io/console'
# Required by yajl for decoding
require 'stringio'
# Used to retrieve hostname
require 'socket'

module OAuthHelper
  def configure_oauth(chosen_description = nil)
    puts "Requesting a OAuth token for git-review."
    puts "This procedure will grant access to your public and private repositories."
    puts "You can revoke this authorization by visiting the following page: " +
      "https://github.com/settings/applications"
    print "Plese enter your GitHub's username: "
    username = STDIN.gets.chomp
    print "Plese enter your GitHub's password (it won't be stored anywhere): "
    password = STDIN.noecho(&:gets).chomp
    print "\n"

    if chosen_description
      description = chosen_description
    else
      description = "git-review - #{Socket.gethostname}"
      puts "Please enter a descriptiont to associate to this token, it will " +
        "make easier to find it inside of github's application page."
      puts "Press enter to accept the proposed description"
      print "Description [#{description}]:"
      user_description = STDIN.gets.chomp
      description = user_description.empty? ? description : user_description
    end

    uri = URI("https://api.github.com/authorizations")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req =Net::HTTP::Post.new(uri.request_uri)
    req.basic_auth username, password
    req.body = Yajl::Encoder.encode(
      {
        "scopes" => ["repo"],
        "note"   => description
      }
    )

    response = http.request req

    if response.code == '401'
      warn "You provided the wrong username/password, please try again."
      configure_oauth(description)
    elsif response.code == '201'
      parser_response      = Yajl::Parser.parse(response.body)
      settings             = Settings.instance
      settings.oauth_token = parser_response['token']
      settings.username    = username
      settings.save!
      puts "OAuth token successfully created"
    else
      warn "Something went wrong: #{response.body}"
      exit 1
    end
  end

end
