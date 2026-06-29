require "httparty"
require "jwt"

namespace :ghost do
  desc "Create a new post.published webhook"
  task create_webhook: :environment do
    target_url = ENV["GHOST_WEBHOOK_TARGET_URL"]

    body = {
      webhooks: [ {
        event: "post.published",
        name: "Mastodon Hook",
        target_url: target_url,
        secret: ENV["GHOST_WEBHOOK_SECRET"]
      } ]
    }.to_json

    response = HTTParty.post(base_url, headers: ghost_headers, body: body)

    if response.success?
      new_id = response.parsed_response["webhooks"][0]["id"]
      puts "Webhook created successfully! ID: #{new_id}"
    else
      puts "Failed to create webhook: #{response.body}"
    end
  end

  desc "Update a webhook (Usage: GHOST_WEBHOOK_ID=xxx bundle exec rake ...)"
  task update_webhook: :environment do
    id = ENV["GHOST_WEBHOOK_ID"]
    target_url = ENV["GHOST_WEBHOOK_TARGET_URL"]
    if id.blank?
      puts "Error: You must provide a GHOST_WEBHOOK_ID (e.g., GHOST_WEBHOOK_ID=65c... bundle exec rake ghost:update_webhook)"
      exit
    end

    body = {
      webhooks: [ {
        name: "Mastodon Hook",
        target_url: target_url,
        secret: ENV["GHOST_WEBHOOK_SECRET"]
      } ]
    }.to_json

    response = HTTParty.put("#{base_url}#{id}/", headers: ghost_headers, body: body)

    if response.success?
      puts "Webhook #{id} updated successfully."
    else
      puts "Update failed: #{response.body}"
    end
  end

  desc "Delete a specific webhook (Usage: GHOST_WEBHOOK_ID=xxx bundle exec rake ...)"
  task delete_webhook: :environment do
    id = ENV["GHOST_WEBHOOK_ID"]
    if id.blank?
      puts "Error: You must provide a GHOST_WEBHOOK_ID"
      exit
    end

    response = HTTParty.delete("#{base_url}#{id}/", headers: ghost_headers)

    if response.code == 204
      puts "Webhook #{id} deleted."
    else
      puts "Delete failed: #{response.body}"
    end
  end

  private

  def ghost_headers
    api_key = ENV["GHOST_ADMIN_API_KEY"]
    if api_key.blank? || !api_key.include?(":")
      puts "Error: GHOST_ADMIN_API_KEY is not set or invalid (format should be id:secret)"
      exit
    end

    id, secret = api_key.split(":")

    # Ghost JWT setup
    header = { alg: "HS256", typ: "JWT", kid: id }
    payload = { iat: Time.now.to_i, exp: Time.now.to_i + 300, aud: "/admin/" }
    token = JWT.encode(payload, [ secret ].pack("H*"), "HS256", header)

    { "Authorization" => "Ghost #{token}", "Content-Type" => "application/json" }
  end

  def base_url
    url = ENV["GHOST_URL"]
    if url.blank?
      puts "Error: GHOST_URL environment variable is missing."
      exit
    end
    "#{url}/ghost/api/admin/webhooks/"
  end
end
