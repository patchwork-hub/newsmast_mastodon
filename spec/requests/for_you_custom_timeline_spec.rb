# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "ForYouCustomTimeline", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "GET /api/v1/timelines/for_you_custom_timeline returns personalized timeline for authenticated user" do
    require_host!
    fake_redis = instance_double("Redis", zrange: [])
    allow_any_instance_of(NewsmastMastodon::ForYouFeed).to receive(:redis).and_return(fake_redis)

    get "/api/v1/timelines/for_you_custom_timeline", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to be_an(Array)
  end

  it "GET /api/v1/timelines/for_you_custom_timeline returns 401 when unauthenticated" do
    require_host!
    get "/api/v1/timelines/for_you_custom_timeline"

    expect(response).to have_http_status(:unauthorized)
  end
end
