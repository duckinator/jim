require_relative "http"
require "base64"
require "date"
require "etc"

module Jim
  class Client
    def initialize(base_uri)
      @base_uri = base_uri
    end

    def sign_in(username, password, otp=nil)
      headers = {}

      otp&.strip!

      needs_mfa = !otp.nil? && !otp.empty?

      headers["OTP"] = otp if needs_mfa

      #possible_scopes = [:index_rubygems, :push_rubygem, :yank_rubygem, :add_owner, :remove_owner, :access_webhooks]
      scopes = {
        index_rubygems: true,
        push_rubygem: false,
        yank_rubygem: false,
      }

      puts "Please choose which scopes you want your API key to have:"
      scopes.each do |k, v|
        begin
          if scopes[k]
            print "#{k}? [Y/n] "
          else
            print "#{k}? [y/N] "
          end
          result = STDIN.gets.strip.downcase
        end until ['y', 'n', ''].include?(result)
        scopes[k] = (result == 'y') || (result.empty? && scopes[k])
      end

      name = "jim--#{Etc.uname[:nodename]}-#{Etc.getlogin}-#{DateTime.now.strftime('%Y-%m-%dT%H%M%S')}"

      form_data = {
        name: name,
        **scopes,
      }

      key = post(
        "/api/v1/api_key",
        headers: headers,
        form_data: form_data,
        basic_auth: [username, password]
      ).or_raise!.read_body.strip

      Config.save_api_key(name, @base_uri, key, scopes, needs_mfa)
    end

    def update_scopes
    end

    private def get(endpoint, *args, **kwargs)
      Jim::HTTP.get(@base_uri + endpoint, *args, **kwargs)
    end

    private def post(endpoint, *args, **kwargs)
      Jim::HTTP.post(@base_uri + endpoint, *args, **kwargs)
    end
  end
end
