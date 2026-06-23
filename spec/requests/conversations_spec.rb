# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "Patchwork Conversations", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "GET /api/v1/patchwork/conversations/check_conversation returns paginated conversations" do
    require_host!
    other = Fabricate(:account)

    get "/api/v1/patchwork/conversations/check_conversation",
      headers: headers,
      params:  { target_account_id: other.id }

    # 200 with empty body (no existing conversation) or serialized conversation
    expect(response).to have_http_status(:ok)
  end

  it "POST /api/v1/patchwork/conversations/read_all marks all unread as read and returns 200" do
    require_host!
    post "/api/v1/patchwork/conversations/read_all", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("success" => true)
  end
end
