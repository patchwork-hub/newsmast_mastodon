# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "Patchwork Relays", type: :request do
  let(:owner_role) do
    UserRole.find_by(name: 'Owner') ||
      UserRole.create!(name: 'Owner', position: 1000, permissions_as_keys: %w[administrator], highlighted: true)
  end
  let(:owner) do
    u = Fabricate(:owner_user)
    u.update_column(:approved, true)
    u.update_column(:role_id, owner_role.id)
    u
  end
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)      { Fabricate(:accessible_access_token, resource_owner_id: owner.id, application: client_app, scopes: token_scopes) }
  let(:headers)    { { "Authorization" => "Bearer #{token.token}" } }

  it "POST /patchwork/relays allows admin to create a relay" do
    require_host!
    inbox_url = "https://relay#{SecureRandom.hex(4)}.example.com/inbox"
    allow_any_instance_of(Relay).to receive(:enable!)

    post "/api/v1/patchwork/relays",
      headers: headers,
      params:  { inbox_url: inbox_url }

    expect(response).to have_http_status(:ok)
  end

  it "DELETE /patchwork/relays/:id allows admin to destroy a relay" do
    require_host!
    relay = Fabricate(:relay)

    delete "/api/v1/patchwork/relays/#{relay.id}", headers: headers

    expect(response).to have_http_status(:ok)
  end

  it "POST /patchwork/relays returns 403 for non-admin" do
    require_host!
    regular_user  = Fabricate(:user, approved: true)
    regular_token = Fabricate(:accessible_access_token, resource_owner_id: regular_user.id, application: client_app, scopes: token_scopes)

    post "/api/v1/patchwork/relays",
      headers: { "Authorization" => "Bearer #{regular_token.token}" },
      params:  { inbox_url: "https://relay.example.com/inbox" }

    expect(response).to have_http_status(:forbidden)
  end
end
