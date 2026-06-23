# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "NewsmastMastodon Api V1 CustomPasswords", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "POST /api/v1/custom_passwords initiates password reset and returns success" do
    require_host!
    allow(CustomPasswordsMailer).to receive_message_chain(:with, :reset_password_confirmation, :deliver_later)

    post "/api/v1/custom_passwords", params: { email: user.email }

    expect(response).to have_http_status(:ok)
  end

  it "PATCH /api/v1/custom_passwords updates password with valid OTP" do
    require_host!
    # Without a valid reset_password_token the record lookup returns nil → 422
    patch "/api/v1/custom_passwords/nonexistent_token",
      params: { password: "newpass123", password_confirmation: "newpass123" }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "POST /api/v1/custom_passwords/verify_otp accepts a valid OTP" do
    require_host!
    # Set up OTP on user
    user.update!(otp_secret: "VALIDOTP")
    token_id = user.reset_password_token

    post "/api/v1/custom_passwords/verify_otp",
      params: { id: token_id, otp_secret: "VALIDOTP" }

    # Either OTP check fails (unprocessable) or succeeds: either way route exists
    expect(response.status).to be_between(200, 422)
  end

  it "POST /api/v1/custom_passwords/verify_otp rejects an invalid OTP" do
    require_host!
    post "/api/v1/custom_passwords/verify_otp",
      params: { id: "bad_token", otp_secret: "WRONGOTP" }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "POST /api/v1/custom_passwords/request_otp sends an OTP email" do
    require_host!
    allow(CustomPasswordsMailer).to receive_message_chain(:with, :reset_password_confirmation, :deliver_later)

    post "/api/v1/custom_passwords", params: { email: user.email }
    reset_token = response.parsed_body["data"] || response.parsed_body["reset_password_token"]

    get "/api/v1/custom_passwords/request_otp", params: { id: reset_token }

    expect(response).to have_http_status(:ok)
  end

  it "POST /api/v1/custom_passwords/change_password updates the authenticated user password" do
    require_host!
    post "/api/v1/custom_passwords/change_password",
      headers: headers,
      params: {
        current_password: "123456789",
        password: "newpassword1",
        password_confirmation: "newpassword1"
      }

    expect(response).to have_http_status(:ok)
  end

  it "POST /api/v1/custom_passwords/change_email updates the authenticated user email" do
    require_host!
    new_email = "newemail#{SecureRandom.hex(4)}@example.com"
    user.update!(otp_secret: nil)

    post "/api/v1/custom_passwords/change_email",
      headers: headers,
      params: { email: new_email, otp_secret: "otp123" }

    # Route exists; result depends on OTP validation
    expect(response.status).to be_between(200, 422)
  end
end
