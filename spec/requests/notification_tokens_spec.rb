# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "NotificationTokens", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }
  let(:device_token) { SecureRandom.hex(16) }

  it "POST /api/v1/notification_tokens creates a token and returns 200" do
    require_host!
    post "/api/v1/notification_tokens",
      headers: headers,
      params: { notification_token: device_token, platform_type: "android" }

    expect(response).to have_http_status(:ok)
  end

  it "POST /api/v1/notification_tokens with a duplicate token returns an appropriate error" do
    require_host!
    NewsmastMastodon::NotificationToken.create!(
      account_id: user.account.id,
      notification_token: device_token,
      platform_type: "android"
    )

    post "/api/v1/notification_tokens",
      headers: headers,
      params: { notification_token: device_token, platform_type: "android" }

    body = response.parsed_body
    expect(response).to have_http_status(:ok)
    expect(body).to include("message")
  end

  it "DELETE /api/v1/notification_tokens/revoke_notification_token revokes the token" do
    require_host!
    NewsmastMastodon::NotificationToken.create!(
      account_id: user.account.id,
      notification_token: device_token,
      platform_type: "android"
    )

    post "/api/v1/notification_tokens/revoke_token",
      headers: headers,
      params: { notification_token: device_token }

    expect(response).to have_http_status(:ok)
  end

  it "POST /api/v1/notification_tokens/update_mute updates the mute status" do
    require_host!
    NewsmastMastodon::NotificationToken.create!(
      account_id: user.account.id,
      notification_token: device_token,
      platform_type: "android"
    )

    post "/api/v1/notification_tokens/update_mute",
      headers: headers,
      params: { mute: true }

    expect(response).to have_http_status(:ok)
  end

  it "GET /api/v1/notification_tokens/get_mute_status returns the current mute state" do
    require_host!
    NewsmastMastodon::NotificationToken.create!(
      account_id: user.account.id,
      notification_token: device_token,
      platform_type: "android"
    )

    get "/api/v1/notification_tokens/get_mute_status", headers: headers

    expect(response).to have_http_status(:ok)
  end
end
