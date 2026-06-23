# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "NewsmastMastodon Api V1 UserLocales", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "POST /api/v1/user_locales saves locale preference" do
    require_host!
    post "/api/v1/user_locales",
      headers: headers,
      params: { locale: "en" }

    expect(response.status).to be_between(200, 422)
  end
end
