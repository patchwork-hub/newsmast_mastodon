# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "EmailSettings", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "POST /api/v1/patchwork/email_settings/notification updates email notification preferences" do
    require_host!
    post "/api/v1/patchwork/email_settings/notification",
      headers: headers,
      params: { allowed: true }

    expect(response).to have_http_status(:ok)
  end

  it "GET /api/v1/patchwork/email_settings returns the current email notification settings" do
    require_host!
    get "/api/v1/patchwork/email_settings", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to have_key("data")
  end

  it "POST /api/v1/patchwork/email_settings/notification unauthenticated returns 401" do
    require_host!
    post "/api/v1/patchwork/email_settings/notification", params: { allowed: true }

    expect(response).to have_http_status(:unauthorized)
  end
end
