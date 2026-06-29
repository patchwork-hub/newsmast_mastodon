# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "PatchworkSettings (Leicester notifications)", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "GET /api/v1/accounts/leicester_notification returns the current Leicester notification setting" do
    require_host!
    get "/api/v1/accounts/leicester_notification", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "leicester_notification")).to be_in([ true, false ])
  end

  it "POST /api/v1/accounts/leicester_notification updates the Leicester notification setting" do
    require_host!
    post "/api/v1/accounts/leicester_notification",
      headers: headers,
      params: { allowed: "true" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "leicester_notification")).to be(true)
  end

  it "GET /api/v1/accounts/leicester_notification unauthenticated returns 401" do
    require_host!
    get "/api/v1/accounts/leicester_notification"

    expect(response).to have_http_status(:unauthorized)
  end

  it "GET /api/v1/accounts/article_notifications returns the current article notifications setting" do
    require_host!
    get "/api/v1/accounts/article_notifications", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "article_notifications")).to be_in([ true, false ])
  end

  it "POST /api/v1/accounts/article_notifications updates the article notifications setting" do
    require_host!
    post "/api/v1/accounts/article_notifications",
      headers: headers,
      params: { allowed: "true" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "article_notifications")).to be(true)
  end

  it "GET /api/v1/accounts/article_notifications unauthenticated returns 401" do
    require_host!
    get "/api/v1/accounts/article_notifications"

    expect(response).to have_http_status(:unauthorized)
  end
end
