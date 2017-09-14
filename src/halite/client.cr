require "./request"
require "./response"

require "http/client"

module Halite
  # Clients make requests and receive responses
  class Client
    include Chainable

    def initialize(@default_options : Halite::Options = Optionns.new)
    end

    def initialize(default_options : (Hash(String, _) | NamedTuple) = {} of String => String)
      @default_options = Options.new(default_options)
    end

    # Make an HTTP request
    def request(verb : String, uri : String, options : (Hash(String, _) | NamedTuple) = {"headers" => nil, "params" => nil, "form" => nil, "json" => nil}) : Halite::Response
      options = @default_options.merge(options)

      uri = make_request_uri(uri, options)
      body = make_request_body(options)
      headers = make_request_headers(options, body.headers)

      request = Request.new(verb, uri, headers, body.body)
      perform(request, options)
    end

    # Perform a single (no follow) HTTP request
    private def perform(request, options) : Halite::Response
      conn = HTTP::Client.new(request.domain)
      conn.connect_timeout = options.timeout.connect.not_nil! if options.timeout.connect
      conn.read_timeout = options.timeout.read.not_nil! if options.timeout.read

      conn_response = conn.exec(request.verb, request.full_path, request.headers, request.body)
      response = Response.new(conn_response)
    end

    # Merges query params if needed
    private def make_request_uri(uri : String, options : Halite::Options) : String
      uri = URI.parse uri
      if params = options.params
        query = HTTP::Params.escape(params)
        uri.query = [uri.query, query].compact.join("&") unless query.empty?
      end

      uri.path = "/" if uri.path.to_s.empty?
      uri.to_s
    end

    # Merges request headers
    private def make_request_headers(options : Halite::Options, content_type : String) : HTTP::Headers
      headers = options.headers
      if !content_type.empty?
        headers.add("Content-Type", content_type)
      end

      headers
    end

    # Merges request headers
    private def make_request_headers(options : Halite::Options, headers : HTTP::Headers?) : HTTP::Headers
      headers = headers ? options.headers.merge!(headers) : options.headers
      options.cookies.add_request_headers(headers)
    end

    # Create the request body object to send
    private def make_request_body(options : Halite::Options) : Halite::Request::Data
      if (form = options.form) && !form.empty?
        return FormData.create form
      elsif (hash = options.json) && !hash.empty?
        body = JSON.build do |builder|
          hash.to_json(builder)
        end
        return Halite::Request::Data.new(body, {"Content-Type" => "application/json"})
      end

      Halite::Request::Data.new("", {} of String => String)
    end
  end
end
