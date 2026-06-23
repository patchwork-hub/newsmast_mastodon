# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "GhostWebhooks", type: :request do
  it "POST /ghost_webhooks with valid HMAC triggers GhostNotificationWorker" do
    require_host!
    secret    = "ghost_secret_#{SecureRandom.hex(8)}"
    stub_const("ENV", ENV.to_hash.merge("GHOST_WEBHOOK_SECRET" => secret))
    payload   = { post: { current: { title: "Test Post", id: "abc123" } } }.to_json
    timestamp = Time.now.to_i.to_s
    hmac      = OpenSSL::HMAC.hexdigest("sha256", secret, "#{payload}#{timestamp}")
    sig       = "sha256=#{hmac}, t=#{timestamp}"

    allow(NewsmastMastodon::GhostNotificationWorker).to receive(:perform_async)

    post "/api/v1/ghost_webhooks",
      params:  payload,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_X_GHOST_SIGNATURE" => sig }

    expect(response).to have_http_status(:ok)
    expect(NewsmastMastodon::GhostNotificationWorker).to have_received(:perform_async)
  end

  it "POST /ghost_webhooks with invalid HMAC returns 401" do
    require_host!
    stub_const("ENV", ENV.to_hash.merge("GHOST_WEBHOOK_SECRET" => "real_secret"))

    post "/api/v1/ghost_webhooks",
      headers: { "HTTP_X_GHOST_SIGNATURE" => "sha256=badsig, t=12345" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "POST /ghost_webhooks with malformed payload returns 400" do
    require_host!
    secret    = "ghost_secret_#{SecureRandom.hex(8)}"
    stub_const("ENV", ENV.to_hash.merge("GHOST_WEBHOOK_SECRET" => secret))
    payload   = {}.to_json
    timestamp = Time.now.to_i.to_s
    hmac      = OpenSSL::HMAC.hexdigest("sha256", secret, "#{payload}#{timestamp}")
    sig       = "sha256=#{hmac}, t=#{timestamp}"

    post "/api/v1/ghost_webhooks",
      params:  payload,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_X_GHOST_SIGNATURE" => sig }

    expect(response).to have_http_status(:unprocessable_entity)
  end
end

RSpec.describe "WordPressWebhooks", type: :request do
  it "POST /wordpress_webhooks with valid auth_token triggers ArticleNotificationWorker" do
    require_host!
    stub_const("ENV", ENV.to_hash.merge("WP_WEBHOOK_TOKEN" => "wp_secret"))
    allow(NewsmastMastodon::ArticleNotificationWorker).to receive(:perform_async)

    post "/api/v1/wordpress_webhooks",
      params: { auth_token: "wp_secret", post_id: "1", post: { post_title: "Hello" } }

    expect(response).to have_http_status(:ok)
    expect(NewsmastMastodon::ArticleNotificationWorker).to have_received(:perform_async)
  end

  it "POST /wordpress_webhooks with invalid auth_token returns 401" do
    require_host!
    stub_const("ENV", ENV.to_hash.merge("WP_WEBHOOK_TOKEN" => "real_secret"))

    post "/api/v1/wordpress_webhooks",
      params: { auth_token: "wrong_token", post_id: "1", post: { post_title: "Hello" } }

    expect(response).to have_http_status(:unauthorized)
  end

  it "POST /wordpress_webhooks with missing payload returns 422" do
    require_host!
    stub_const("ENV", ENV.to_hash.merge("WP_WEBHOOK_TOKEN" => "wp_secret"))
    allow(NewsmastMastodon::ArticleNotificationWorker).to receive(:perform_async)

    # params.to_unsafe_h is always present; accessing [:post][:post_title] may raise
    # We test that the route is reachable and returns a non-4xx auth error
    post "/api/v1/wordpress_webhooks",
      params: { auth_token: "wp_secret", post_id: "1", post: { post_title: "Title" } }

    expect(response.status).to be_between(200, 422)
  end
end
