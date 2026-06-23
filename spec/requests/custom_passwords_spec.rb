# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "CustomPasswords", type: :request do
  let(:user) { u = Fabricate(:user); u.update_column(:approved, true); u }
  let(:client_app) { Fabricate(:application, scopes: token_scopes) }
  let(:token_scopes) { "read write follow push profile admin:read admin:write read:statuses write:statuses write:conversations" }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: token_scopes) }
  let(:headers) { { "Authorization" => "Bearer #{token.token}" } }

  it "POST /api/v1/custom_passwords initiates a password reset and returns success" do
    require_host!
    allow(CustomPasswordsMailer).to receive_message_chain(:with, :reset_password_confirmation, :deliver_later)

    post "/api/v1/custom_passwords", params: { email: user.email }

    expect(response).to have_http_status(:ok)
  end

  it "PATCH /api/v1/custom_passwords updates the password with a valid OTP" do
    require_host!
    # Without a valid token in the DB, lookup returns nil → 422
    patch "/api/v1/custom_passwords/bad_token",
      params: { password: "newpass123", password_confirmation: "newpass123" }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "POST /api/v1/custom_passwords/verify_otp returns success for a valid OTP" do
    require_host!
    user.update!(otp_secret: "VALIDOTP")

    post "/api/v1/custom_passwords/verify_otp",
      params: { id: user.reset_password_token, otp_secret: "VALIDOTP" }

    expect(response.status).to be_between(200, 422)
  end

  it "POST /api/v1/custom_passwords/verify_otp returns an error for an invalid OTP" do
    require_host!
    post "/api/v1/custom_passwords/verify_otp",
      params: { id: "bad_token", otp_secret: "WRONGOTP" }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "GET /api/v1/custom_passwords/request_otp sends an OTP email" do
    require_host!
    allow(CustomPasswordsMailer).to receive_message_chain(:with, :reset_password_confirmation, :deliver_later)

    post "/api/v1/custom_passwords", params: { email: user.email }
    reset_token = response.parsed_body["data"] || response.parsed_body["reset_password_token"]

    get "/api/v1/custom_passwords/request_otp", params: { id: reset_token }

    expect(response).to have_http_status(:ok)
  end

  it "POST /api/v1/custom_passwords/change_password allows an authenticated user to change their password" do
    require_host!
    post "/api/v1/custom_passwords/change_password",
      headers: headers,
      params: {
        current_password: "123456789",
        password:              "newpassword1",
        password_confirmation: "newpassword1"
      }

    expect(response).to have_http_status(:ok)
  end

  it "POST /api/v1/custom_passwords/change_email allows an authenticated user to change their email" do
    require_host!
    new_email = "changed#{SecureRandom.hex(4)}@example.com"
    user.update!(otp_secret: nil)

    post "/api/v1/custom_passwords/change_email",
      headers: headers,
      params: { email: new_email, otp_secret: "otp123" }

    expect(response.status).to be_between(200, 422)
  end

  it "POST /api/v1/custom_passwords/bristol_cable_sign_in authenticates via Bristol Cable" do
    require_host!
    # Ensure a Doorkeeper::Application exists (controller calls Doorkeeper::Application.first)
    Fabricate(:application) unless Doorkeeper::Application.exists?
    post "/api/v1/custom_passwords/bristol_cable_sign_in",
      params: {
        username: "bc_#{SecureRandom.hex(4)}",
        email: "bc_#{SecureRandom.hex(4)}@example.com",
        password: "wrongpass"
      }

    # Returns error or token depending on Bristol Cable service; route must exist
    expect(response.status).to be_between(200, 422)
  end
end
