# frozen_string_literal: true


module NewsmastMastodon
  class ReblogPostService < BaseService
    CACHE_KEY = "reblog_access_token"

    def initialize(status_url)
      @status_url = status_url
      @base_url = ENV["REBLOG_INSTANCE_URL"]
      @email = ENV["REBLOG_EMAIL"]
      @password = ENV["REBLOG_PASSWORD"]
    end

    def call
      token = fetch_token
      unless token.present?
        Rails.cache.delete(CACHE_KEY)
        Rails.logger.error "[ReblogPostService] Authentication failed: Token not found"
      end
      status_id = NewsmastMastodon::SearchPostService.new(@base_url, token, @status_url).call
    rescue StandardError => e
      Rails.logger.error "[ReblogPostService] Error: #{e.class} - #{e.message}"
      raise e
    end

    private

    def fetch_token
      cached = Rails.cache.read(CACHE_KEY)

      if cached.present? && !token_expired?(cached)
        return cached[:access_token]
      end

      token_data = NewsmastMastodon::AuthenticateUserService.new(@base_url, @email, @password).call
      Rails.cache.write(CACHE_KEY, token_data)
      token_data[:access_token]
    end

    def token_expired?(token_data)
      return true unless token_data[:created_at].present?

      expires_at = Time.at(token_data[:created_at]) + 24.hour
      Time.current >= expires_at
    end
  end
end
