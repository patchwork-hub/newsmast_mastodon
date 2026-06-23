# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "AccountDeletion", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "DELETE /api/v1/patchwork/account_deletion/:id deletes account and returns accepted" do
    require_host!
    service = instance_double(DeleteAccountService, call: nil)

    allow(DeleteAccountService).to receive(:new).and_return(service)

    delete "/api/v1/patchwork/account_deletion/#{user.account.id}", headers: headers

    expect(DeleteAccountService).to have_received(:new)
    expect(service).to have_received(:call).with(user.account, reserve_email: false, reserve_username: false)
    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to have_key("data")
  end

  it "DELETE /api/v1/patchwork/account_deletion/:id with unknown account returns 404" do
    require_host!

    delete "/api/v1/patchwork/account_deletion/-1", headers: headers

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to have_key("error")
  end

  it "DELETE /api/v1/patchwork/account_deletion/:id unauthenticated returns 401" do
    require_host!

    delete "/api/v1/patchwork/account_deletion/#{user.account.id}"

    expect(response).to have_http_status(:unauthorized)
  end
end
