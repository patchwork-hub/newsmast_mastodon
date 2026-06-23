# frozen_string_literal: true


module NewsmastMastodon
  class BoostPostService < BaseService
    include RoutingHelper
    require "net/http"
    require "uri"
    require "json"

    def initialize(post_url)
      @post_url = post_url
      @base_url = ENV["BOOST_POST_INSTANCE_URL"]
      @api_key = ENV["BOOST_POST_API_KEY"]
      @api_secret = ENV["BOOST_POST_API_SECRET"]
      @endpoint = "/api/v1/statuses/boost_post"
    end

    def call
      payload  = create_payload
      response = perform_request(payload)
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error "[BoostPostService] Error: #{e.class} - #{e.message}"
      { status: :error, body: e.message }
    end

    private

    def perform_request(payload)
      uri  = URI.join(@base_url, @endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      request["x-api-key"]    = @api_key
      request["x-api-secret"] = @api_secret
      request.body            = payload.to_json

      http.request(request)
    end

    def parse_response(response)
      parsed_body = JSON.parse(response.body) rescue { "status" => "error", "body" => "Invalid JSON response" }
      {
        status: parsed_body["status"] || :error,
        body:   parsed_body["body"]
      }
    end

    def create_payload
      {
        post_url: @post_url,
        boost_post_username: ENV["BOOST_POST_USERNAME"],
        boost_post_user_domain: ENV["BOOST_POST_USER_DOMAIN"]
      }
    end
  end
end
