# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Api::V1::CrossInstancePushController do
  it "sanitizes Rails parameters into a native Hash with string keys and values" do
    controller = described_class.new
    allow(controller).to receive(:params).and_return(
      ActionController::Parameters.new(data: { noti_type: "follow", destination_id: 123, visibility: "" })
    )

    data = controller.send(:sanitized_data)

    expect(data).to be_instance_of(Hash)
    expect(data).to eq("noti_type" => "follow", "destination_id" => "123", "visibility" => "")
  end
end

RSpec.describe "CrossInstancePush", type: :request do
  def signed_headers(payload, secret, timestamp: Time.now.to_i.to_s)
    hmac = OpenSSL::HMAC.hexdigest("sha256", secret, "#{payload}#{timestamp}")
    { "CONTENT_TYPE" => "application/json", "X-Signature" => "sha256=#{hmac}, t=#{timestamp}" }
  end

  it "POST /cross_instance_push with a valid signature enqueues CrossInstancePushWorker" do
    require_host!
    secret  = "cross_instance_secret_#{SecureRandom.hex(8)}"
    stub_const("ENV", ENV.to_hash.merge("CROSS_INSTANCE_PUSH_SECRET" => secret))
    payload = { username: "alice", title: "Hello", body: "World", data: { reason: "broadcast" } }.to_json

    allow(NewsmastMastodon::CrossInstancePushWorker).to receive(:perform_async)

    post "/api/v1/cross_instance_push", params: payload, headers: signed_headers(payload, secret)

    expect(response).to have_http_status(:accepted)
    expect(NewsmastMastodon::CrossInstancePushWorker).to have_received(:perform_async).with(
      "alice", "Hello", "World", { "reason" => "broadcast" }
    )
  end

  it "POST /cross_instance_push with an invalid signature returns 401" do
    require_host!
    stub_const("ENV", ENV.to_hash.merge("CROSS_INSTANCE_PUSH_SECRET" => "real_secret"))

    post "/api/v1/cross_instance_push",
      params: { username: "alice", title: "Hello", body: "World" }.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "X-Signature" => "sha256=badsig, t=#{Time.now.to_i}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "POST /cross_instance_push with a stale timestamp returns 401" do
    require_host!
    secret  = "cross_instance_secret_#{SecureRandom.hex(8)}"
    stub_const("ENV", ENV.to_hash.merge("CROSS_INSTANCE_PUSH_SECRET" => secret))
    payload = { username: "alice", title: "Hello", body: "World" }.to_json
    stale_timestamp = (Time.now.to_i - 3600).to_s

    post "/api/v1/cross_instance_push", params: payload, headers: signed_headers(payload, secret, timestamp: stale_timestamp)

    expect(response).to have_http_status(:unauthorized)
  end

  it "POST /cross_instance_push with a missing body field returns 422" do
    require_host!
    secret  = "cross_instance_secret_#{SecureRandom.hex(8)}"
    stub_const("ENV", ENV.to_hash.merge("CROSS_INSTANCE_PUSH_SECRET" => secret))
    payload = { username: "alice", title: "Hello" }.to_json

    post "/api/v1/cross_instance_push", params: payload, headers: signed_headers(payload, secret)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
