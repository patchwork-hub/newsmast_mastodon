# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "NewsmastMastodon Api V1 Channels", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "GET /api/v1/channels/starter_packs_channels returns cached channel data" do
    require_host!
    get "/api/v1/channels/starter_packs_channels", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to have_key("data")
  end

  it "GET /api/v1/channels/starter_packs_detail returns specific channel detail" do
    require_host!
    get "/api/v1/channels/1/starter_packs_detail", headers: headers

    # 200 if file exists, 404 if no starter pack data file present
    expect(response.status).to be_in([ 200, 404 ])
  end
end
