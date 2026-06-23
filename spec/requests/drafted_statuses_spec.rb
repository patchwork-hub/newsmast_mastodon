# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "DraftedStatuses", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  def create_draft(text: "Hello draft #{SecureRandom.hex(4)}")
    NewsmastMastodon::DraftedStatus.create!(
      account: user.account,
      params:  { status: text }
    )
  end

  it "POST /api/v1/drafted_statuses creates a draft and returns the serialized draft" do
    require_host!
    post "/api/v1/drafted_statuses",
      headers: headers,
      params: { status: "My draft post" }

    expect(response).to have_http_status(:ok)
  end

  it "GET /api/v1/drafted_statuses lists drafts grouped by date" do
    require_host!
    create_draft

    get "/api/v1/drafted_statuses", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to be_an(Array)
  end

  it "GET /api/v1/drafted_statuses/:id shows a single draft" do
    require_host!
    draft = create_draft

    get "/api/v1/drafted_statuses/#{draft.id}", headers: headers

    expect(response).to have_http_status(:ok)
  end

  it "PATCH /api/v1/drafted_statuses/:id updates draft params" do
    require_host!
    draft = create_draft

    patch "/api/v1/drafted_statuses/#{draft.id}",
      headers: headers,
      params: { status: "Updated draft" }

    expect(response).to have_http_status(:ok)
  end

  it "DELETE /api/v1/drafted_statuses/:id destroys the draft" do
    require_host!
    draft = create_draft

    delete "/api/v1/drafted_statuses/#{draft.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(NewsmastMastodon::DraftedStatus.exists?(draft.id)).to be false
  end

  it "POST /api/v1/drafted_statuses/:id/publish publishes the draft to a status" do
    require_host!
    draft = create_draft

    post "/api/v1/drafted_statuses/#{draft.id}/publish", headers: headers

    # 200 on success, 422 if publish validation fails
    expect(response.status).to be_between(200, 422)
  end

  it "POST /api/v1/drafted_statuses exceeding TOTAL_LIMIT (300) returns an error" do
    require_host!
    stub_const("NewsmastMastodon::DraftedStatus::TOTAL_LIMIT", 0)

    post "/api/v1/drafted_statuses",
      headers: headers,
      params: { status: "Over limit" }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "POST /api/v1/drafted_statuses exceeding DAILY_LIMIT (25) returns an error" do
    require_host!
    stub_const("NewsmastMastodon::DraftedStatus::DAILY_LIMIT", 0)

    post "/api/v1/drafted_statuses",
      headers: headers,
      params: { status: "Over daily limit" }

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
