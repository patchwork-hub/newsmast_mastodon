# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::CrossInstancePushClient, type: :service do
  it "does nothing when target URL or secret is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("CROSS_INSTANCE_PUSH_TARGET_URL").and_return(nil)
    allow(ENV).to receive(:[]).with("CROSS_INSTANCE_PUSH_SECRET").and_return("secret")

    expect(described_class).not_to receive(:post)

    result = described_class.deliver(username: "alice", title: "Title", body: "Body")

    expect(result).to be_nil
  end

  it "signs the payload and posts it to the partner's endpoint" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("CROSS_INSTANCE_PUSH_TARGET_URL").and_return("https://instance-b.example/api/v1/cross_instance_push")
    allow(ENV).to receive(:[]).with("CROSS_INSTANCE_PUSH_SECRET").and_return("shared-secret")

    response = instance_double("HTTPartyResponse", success?: true, code: 202, body: "ok")
    captured = {}
    allow(described_class).to receive(:post) do |url, **kwargs|
      captured[:url] = url
      captured[:headers] = kwargs[:headers]
      captured[:body] = kwargs[:body]
      response
    end

    described_class.deliver(username: "alice", title: "Title", body: "Body", data: { reason: "broadcast" })

    expect(captured[:url]).to eq("https://instance-b.example/api/v1/cross_instance_push")

    payload = JSON.parse(captured[:body])
    expect(payload).to eq("username" => "alice", "title" => "Title", "body" => "Body", "data" => { "reason" => "broadcast" })

    sig_header = captured[:headers]["X-Signature"]
    parts = sig_header.split(", ").map { |part| part.split("=", 2) }.to_h
    expected_hash = OpenSSL::HMAC.hexdigest("sha256", "shared-secret", "#{captured[:body]}#{parts['t']}")
    expect(parts["sha256"]).to eq(expected_hash)
  end
end
