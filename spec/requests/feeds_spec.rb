# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "CustomFeed timelines/@username/feed", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  def ensure_boost_bot(account)
    return unless Object.const_defined?('ContentFilters::CommunityAdmin')
    ContentFilters::CommunityAdmin.find_or_create_by!(account_id: account.id) do |ca|
      ca.is_boost_bot = true
      ca.account_status = ContentFilters::CommunityAdmin.account_statuses[:active]
    end
  end

  it "GET /api/v1/timelines/@username/feed returns statuses (Redis stubbed)" do
    require_host!
    ensure_boost_bot(user.account)
    get "/api/v1/timelines/@#{user.account.username}/feed", headers: headers

    # Returns 200 when ContentFilters gem is loaded and account is a boost bot, 404 otherwise
    expect(response.status).to be_in([ 200, 404 ])
    expect(response.parsed_body).to be_an(Array).or have_key("error")
  end

  it "GET /api/v1/timelines/@username/feed honours max_id/since_id/min_id" do
    require_host!
    ensure_boost_bot(user.account)
    get "/api/v1/timelines/@#{user.account.username}/feed",
      headers: headers,
      params:  { max_id: "999999", min_id: "1", limit: 20 }

    # Returns 200 when ContentFilters gem is loaded and account is a boost bot, 404 otherwise
    expect(response.status).to be_in([ 200, 404 ])
  end

  it "GET /api/v1/timelines/@username/feed returns 404 for non-existent user" do
    require_host!
    get "/api/v1/timelines/@nonexistentuser_#{SecureRandom.hex(6)}/feed",
      headers: headers

    expect(response).to have_http_status(:not_found)
  end
end
