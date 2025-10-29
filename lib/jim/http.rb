# frozen_string_literal: true

# This file was unceremoniously yoinked from okay/http.

require_relative "version"
require "net/https"
#require "cacert"

#Cacert.set_in_env

# :nodoc:
module Net
  # :nodoc:
  class HTTPResponse
    # Returns false if the server encountered an error, true otherwise.
    def okay?
      self.value
      true
    rescue Net::HTTPExceptions
      false
    end

    # Raises an exception if the request failed. (A fatal equivalent of +okay?+)
    def or_raise!
      self.value
      self
    end

    # Converts the result from JSON if +okay?+ returns true; otherwise returns
    # nil.
    #
    # Can be combined with +or_raise!+ to get a JSON result or raise an
    # exception:
    #
    #     Okay::HTTP.get("https://example.org/blah.json").or_raise!.from_json
    def from_json
      return nil unless okay?

      require "json"

      JSON.parse(body)
    end
  end
end

module Jim
  ##
  # A wrapper around Net::HTTP, focused on ease of use and flexibility.
  module HTTP
    class RedirectLimitError < StandardError; end

    DEFAULT_REDIRECT_LIMIT = 10

    # Make an HTTP GET request.
    #
    # @param url [String] The URL to request.
    # @param parameters [Hash] A hash representing a query string.
    def self.get(url, parameters: {}, headers: {}, basic_auth: nil)
      send_request(:Get, url, parameters, nil, headers)
    end

    # Make an HTTP POST request.
    #
    # @param url [String] The URL to request.
    # @param data [String] Raw data to for the body of the request.
    # @param form_data [Hash] Data for the request body, encoded as though it
    #   were a form.
    def self.post(url, data: nil, form_data: nil, headers: {}, basic_auth: nil)
      if !data.nil? && !form_data.nil?
        raise ArgumentError,
              "cannot specify data and form_data arguments simultaneously."
      end

      if form_data.nil?
        body = data
      else
        body = URI.encode_www_form(form_data)
      end

      send_request(:Post, url, nil, body, headers, basic_auth)
    end

    # Make an HTTP PATCH request.
    #
    # @param url [String] The URL to request.
    # @param data [String] Raw data to for the body of the request.
    def self.patch(url, data: nil, headers: {}, basic_auth: nil)
      send_request(:Patch, url, nil, data, headers, basic_auth)
    end


    # rubocop:disable Metrics/AbcSize

    # Helper method for actually creating a request.
    #
    # @param http_method [Symbol] A symbol representing the class name for
    #   +Net::HTTP+. E.g., +:Get+ for GET requests, +:Post+ for POST, etc.
    # @param url [String] URL for the request.
    # @param parameters [Hash, nil] Request parameters (for the query string).
    # @param body [String, nil] Request body.
    # @param redirect_limit [Numeric] The maximum number of redirects allowed.
    def self.send_request(http_method, url, parameters, body, headers,
                          basic_auth = nil,
                          redirect_limit = DEFAULT_REDIRECT_LIMIT)
      redirect_limit ||= DEFAULT_REDIRECT_LIMIT # FIXME: This shouldn't be needed.
      if redirect_limit <= 0
        raise RedirectLimitError, "request exceeded redirect limit"
      end

      # Convert the URL (a String) into a URI object.
      uri = URI.parse(url)
      host = uri.host
      raise RuntimeError, "URI has no host: #{url}" unless host

      # Set the query string for the request.
      unless parameters.nil? || parameters.empty?
        uri.query = URI.encode_www_form(parameters)
      end

      options = {
        # If the URI starts with "https://", enable SSL/TLS.
        use_ssl: (uri.scheme == "https"),
      }

      # Net::HTTP.start() keeps a connection to the host alive
      # for all requests that occur inside the block.
      Net::HTTP.start(host, uri.port, options) do |http| # steep:ignore ArgumentTypeMismatch

        # Get a reference to the class for the specified request type.
        # E.g., if it's a post request, this returns Net::HTTP::Post.
        request_class = Net::HTTP.const_get(http_method)

        # Create the request object, but don't send it.
        request = request_class.new(uri)

        # If provided, use Basic Auth.
        request.basic_auth(*basic_auth) unless basic_auth.nil?

        headers&.each do |k, v|
          request[k] = v
        end

        # Set the request body, if there is one.
        request.body = body unless body.nil?

        # Send the request, storing the result in +response+.
        response = http.request(request)

        # Handle responses.
        if response.is_a?(Net::HTTPRedirection)
          # Follow a redirect.
          # Decrements +redirect_limit+ while doing so, to avoid redirect loops.
          # NOTE: Does not handle HTTP 307. https://httpstatuses.com/307
          new_url = response["location"]
          if new_url.start_with?("/")
            new_uri = uri.dup
            new_uri.path = response["location"]
            new_url = new_uri.to_s
          elsif new_url.start_with?(".")
            new_uri = uri.dup
            new_uri.path += "/" + response["location"] # steep:ignore NoMethod
            new_url = new_uri.to_s
          end
          send_request(:Get, new_url, parameters, body, headers, basic_auth,
                       redirect_limit - 1)
        else
          response
        end
      end
    end

    # Make +send_request+ a private method.
    private_class_method :send_request
  end
end

