# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "NewsmastMastodon Api V1 Patchwork AlttextSettings", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "PATCH /api/v1/patchwork/alttext_settings toggles alttext_enabled" do
    require_host!
    post "/api/v1/patchwork/alttext_settings/alttext",
      headers: headers,
      params: { enabled: true }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("data")
  end
end
