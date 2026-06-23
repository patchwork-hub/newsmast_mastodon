# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "LocalOnlyPosts", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "GET /api/v1/local_only_posts/getLocalOnlySetting returns server-level setting" do
    require_host!
    get "/api/v1/local_only_posts/getLocalOnlySetting", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to have_key("local_only")
  end
end
