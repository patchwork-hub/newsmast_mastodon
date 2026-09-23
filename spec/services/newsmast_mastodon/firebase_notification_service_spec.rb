# frozen_string_literal: true

require "rails_helper"
require "stringio"
require "json"

RSpec.describe NewsmastMastodon::FirebaseNotificationService, type: :service do
  before do
    described_class.reset_authorizer_cache!
  end

  it "fetches an OAuth access token via Google::Auth (stubbed)" do
    stub_const("NewsmastMastodon::FirebaseNotificationService::BASE_URL", "https://fcm.googleapis.com/v1/projects/test/messages:send")
    stub_const("NewsmastMastodon::FirebaseNotificationService::FILE_NAME", "firebase.json")

    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:open).and_return(StringIO.new("{}"))

    creds = instance_double("GoogleCreds")
    allow(creds).to receive(:fetch_access_token!).and_return({ "access_token" => "abc123" })

    service_account_creds = class_double("Google::Auth::ServiceAccountCredentials", make_creds: creds)
    stub_const("Google::Auth::ServiceAccountCredentials", service_account_creds)

    response = instance_double("HTTPartyResponse", success?: true, body: "ok")
    allow(described_class).to receive(:post).and_return(response)

    described_class.send_notification("tok", "title", "body", {})

    expect(Google::Auth::ServiceAccountCredentials).to have_received(:make_creds)
  end

  it "builds the FCM notification payload correctly" do
    stub_const("NewsmastMastodon::FirebaseNotificationService::BASE_URL", "https://fcm.googleapis.com/v1/projects/test/messages:send")
    stub_const("NewsmastMastodon::FirebaseNotificationService::FILE_NAME", "firebase.json")

    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:open).and_return(StringIO.new("{}"))

    creds = instance_double("GoogleCreds")
    allow(creds).to receive(:fetch_access_token!).and_return({ "access_token" => "abc123" })

    service_account_creds = class_double("Google::Auth::ServiceAccountCredentials", make_creds: creds)
    stub_const("Google::Auth::ServiceAccountCredentials", service_account_creds)

    response = instance_double("HTTPartyResponse", success?: true, body: "ok")
    captured_body = nil
    allow(described_class).to receive(:post) do |_url, **kwargs|
      captured_body = kwargs[:body]
      response
    end

    described_class.send_notification("tok", "Patchwork", "Hello", { a: "1" })

    expect(described_class).to have_received(:post).with(
      "https://fcm.googleapis.com/v1/projects/test/messages:send",
      headers: hash_including("Authorization" => "Bearer abc123"),
      body: kind_of(String)
    )

    parsed = JSON.parse(captured_body)
    expect(parsed.dig("message", "token")).to eq("tok")
    expect(parsed.dig("message", "notification", "title")).to eq("Patchwork")
    expect(parsed.dig("message", "notification", "body")).to eq("Hello")
  end

  it "reuses the same authorizer across multiple sends" do
    stub_const("NewsmastMastodon::FirebaseNotificationService::BASE_URL", "https://fcm.googleapis.com/v1/projects/test/messages:send")
    stub_const("NewsmastMastodon::FirebaseNotificationService::FILE_NAME", "firebase.json")

    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:open).and_return(StringIO.new("{}"))

    creds = instance_double("GoogleCreds")
    allow(creds).to receive(:fetch_access_token!).and_return({ "access_token" => "abc123", "expires_in" => 3600 })

    service_account_creds = class_double("Google::Auth::ServiceAccountCredentials", make_creds: creds)
    stub_const("Google::Auth::ServiceAccountCredentials", service_account_creds)

    response = instance_double("HTTPartyResponse", success?: true, body: "ok")
    allow(described_class).to receive(:post).and_return(response)

    described_class.send_notification("tok1", "title", "body", {})
    described_class.send_notification("tok2", "title2", "body2", {})

    expect(Google::Auth::ServiceAccountCredentials).to have_received(:make_creds).once
    expect(File).to have_received(:open).once
  end

  it "handles invalid/expired tokens gracefully" do
    allow(Rails.logger).to receive(:error)

    stub_const("NewsmastMastodon::FirebaseNotificationService::BASE_URL", "https://fcm.googleapis.com/v1/projects/test/messages:send")
    stub_const("NewsmastMastodon::FirebaseNotificationService::FILE_NAME", "firebase.json")

    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:open).and_return(StringIO.new("{}"))

    creds = instance_double("GoogleCreds")
    allow(creds).to receive(:fetch_access_token!).and_raise(StandardError, "token expired")

    service_account_creds = class_double("Google::Auth::ServiceAccountCredentials", make_creds: creds)
    stub_const("Google::Auth::ServiceAccountCredentials", service_account_creds)

    result = described_class.send_notification("tok", "Patchwork", "Hello", {})

    expect(result).to be_nil
    expect(Rails.logger).to have_received(:error).with(/Exception sending notification: token expired/)
  end
end
