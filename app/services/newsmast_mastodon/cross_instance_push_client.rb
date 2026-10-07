# frozen_string_literal: true

require "httparty"

module NewsmastMastodon
  # Sending side: signs and delivers a cross-instance push request to a
  # partner instance's CrossInstancePushController.
  #
  # ENV configuration:
  #   CROSS_INSTANCE_PUSH_TARGET_URL - full URL of the partner's endpoint,
  #     e.g. https://instance-b.example/api/v1/cross_instance_push
  #   CROSS_INSTANCE_PUSH_SECRET     - secret shared with that partner
  class CrossInstancePushClient
    include HTTParty

    REQUEST_TIMEOUT = 5

    def self.deliver(username:, title:, body:, data: {})
      target_url = ENV["CROSS_INSTANCE_PUSH_TARGET_URL"]
      secret = ENV["CROSS_INSTANCE_PUSH_SECRET"]

      if target_url.blank? || secret.blank?
        Rails.logger.error("Cross-instance push is not configured: CROSS_INSTANCE_PUSH_TARGET_URL/CROSS_INSTANCE_PUSH_SECRET missing")
        return nil
      end

      payload = { username: username, title: title, body: body, data: data }.to_json
      timestamp = Time.now.to_i.to_s
      signature = OpenSSL::HMAC.hexdigest("sha256", secret, "#{payload}#{timestamp}")

      response = post(
        target_url,
        headers: {
          "Content-Type" => "application/json",
          "X-Signature" => "sha256=#{signature}, t=#{timestamp}"
        },
        body: payload,
        timeout: REQUEST_TIMEOUT
      )

      Rails.logger.error("Cross-instance push failed: #{response.code} #{response.body}") unless response.success?

      response
    rescue StandardError => e
      Rails.logger.error("Exception sending cross-instance push: #{e.message}")
      nil
    end
  end
end
