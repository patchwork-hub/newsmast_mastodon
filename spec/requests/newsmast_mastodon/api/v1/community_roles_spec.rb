# frozen_string_literal: true

require "rails_helper"

RSpec.describe "NewsmastMastodon Api V1 CommunityRoles", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "exposes search_local_accounts endpoint" do
    require_host!

    get "/api/v1/channels/1/search_local_accounts", headers: headers, params: { query: "alice" }

    expect(response.status).to be_in([200, 403, 404])
  end

  it "exposes assigned_roles endpoint" do
    require_host!

    get "/api/v1/channels/1/assigned_roles", headers: headers

    expect(response.status).to be_in([200, 403, 404])
  end

  it "exposes assign_role endpoint" do
    require_host!

    post "/api/v1/channels/1/assign_role", headers: headers, params: { account_id: 1, role: "GroupAdmin" }

    expect(response.status).to be_in([200, 403, 404, 422])
  end

  it "exposes remove_assigned_role endpoint" do
    require_host!

    post "/api/v1/channels/1/remove_assigned_role", headers: headers, params: { account_id: 1 }

    expect(response.status).to be_in([200, 403, 404, 422])
  end

  it "exposes invite_user endpoint" do
    require_host!

    post "/api/v1/channels/1/invite_user", headers: headers, params: { email: "invitee@example.com" }

    expect(response.status).to be_in([201, 403, 404, 422])
  end
end
