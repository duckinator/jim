require_relative "config"
require_relative "console"
require_relative "http"
require "date"
require "etc"

module Jim
  class Client
    include Jim::Console

    def initialize(base_uri)
      @base_uri = base_uri
    end

    def sign_in(username, password, otp=nil)
      headers = {} #: Hash[String, String]

      otp&.strip!

      needs_mfa = !otp.nil? && !otp.empty?

      headers["OTP"] = otp if needs_mfa # steep:ignore ArgumentTypeMismatch

      #possible_scopes = [:index_rubygems, :push_rubygem, :yank_rubygem, :add_owner, :remove_owner, :access_webhooks]
      scopes = {
        index_rubygems: true,
        push_rubygem: false,
        yank_rubygem: false,
      }

      puts "Please choose which scopes you want your API key to have:"
      scopes.each do |k, v|
        scopes[k] = prompt_yesno(k, default_to_yes: scopes[k])
      end

      name = "jim--#{Etc.uname[:nodename]}-#{Etc.getlogin}-#{DateTime.now.strftime('%Y-%m-%dT%H%M%S')}"

      form_data = {
        name: name,
        **scopes,
      }

      key = create_api_key(headers, form_data, username, password)

      Config.save_api_key(name, @base_uri, key, scopes, needs_mfa)
    end

    private def create_api_key(headers, form_data, username, password)
      post(
        "/api/v1/api_key",
        headers: headers,
        form_data: form_data,
        basic_auth: [username, password]
      ).or_raise!.read_body.strip
    end

    private def get(endpoint, **kwargs)
      Jim::HTTP.get(@base_uri + endpoint, **kwargs)
    end

    private def post(endpoint, **kwargs)
      Jim::HTTP.post(@base_uri + endpoint, **kwargs)
    end
  end
end
