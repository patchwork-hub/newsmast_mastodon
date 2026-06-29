# frozen_string_literal: true


module NewsmastMastodon
  class ReblogRequestService < BaseService
    require "net/http"

    def call(access_token, status_id)
      url = if Rails.env.development?
              URI("http://localhost:3000/api/v1/statuses/#{status_id}/reblog")
      else
              URI("https://#{ENV['LOCAL_DOMAIN']}/api/v1/statuses/#{status_id}/reblog")
      end

      req = Net::HTTP::Post.new(url)
      req.content_type = "application/json"
      req["Authorization"] = "Bearer #{access_token}"
      req.body = { visibility: "public" }.to_json

      response = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == "https") do |http|
        http.request(req)
      end

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      else
        raise "Reblog creation failed: #{response.body}"
      end
    end
  end
end
