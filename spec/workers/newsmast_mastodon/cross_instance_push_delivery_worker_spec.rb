# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::CrossInstancePushDeliveryWorker, type: :worker do
  it "#perform delegates to CrossInstancePushClient" do
    allow(NewsmastMastodon::CrossInstancePushClient).to receive(:deliver)

    described_class.new.perform("alice", "Title", "Body", { "reason" => "broadcast" })

    expect(NewsmastMastodon::CrossInstancePushClient).to have_received(:deliver).with(
      username: "alice", title: "Title", body: "Body", data: { "reason" => "broadcast" }
    )
  end
end
