# frozen_string_literal: true


module NewsmastMastodon
  class AuthenticateUserService < BaseService
    require "httparty"

    def initialize(base_url, email, password)
      @base_url = base_url
      @email = email
      @password = password
      @endpoint = "/oauth/token"
    end

    def call
      validate_oauth_credentials!
      response = perform_request
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error "[AuthenticateUserService] Error: #{e.class} - #{e.message}"
      raise e
    end

    private

    def validate_oauth_credentials!
      missing_vars = []
      missing_vars << "REBLOG_CLIENT_ID" if ENV["REBLOG_CLIENT_ID"].blank?
      missing_vars << "REBLOG_CLIENT_SECRET" if ENV["REBLOG_CLIENT_SECRET"].blank?

      if missing_vars.any?
        raise ArgumentError, "Missing required environment variables: #{missing_vars.join(', ')}"
      end
    end

    def perform_request
      url = "#{@base_url}#{@endpoint}"

      HTTParty.post(url,
        body: payload.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    def parse_response(response)
      unless response.success?
        raise "Authentication failed: HTTP #{response.code} - #{response.parsed_response['error'] || response.message}"
      end
      {
        access_token: response["access_token"],
        created_at: response["created_at"]
      }
    end

    def payload
      {
        grant_type: "password",
        username: @email,
        password: @password,
        client_id: ENV["REBLOG_CLIENT_ID"],
        client_secret: ENV["REBLOG_CLIENT_SECRET"],
        scope: "read write follow push",
        is_web_login: false
      }
    end
  end
end
