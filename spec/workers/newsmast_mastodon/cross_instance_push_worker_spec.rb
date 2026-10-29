# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::CrossInstancePushWorker, type: :worker do
  it "#perform delegates to CrossInstancePushService" do
    service = instance_double("NewsmastMastodon::CrossInstancePushService", call: true)
    service_class = class_double("NewsmastMastodon::CrossInstancePushService", new: service)
    stub_const("NewsmastMastodon::CrossInstancePushService", service_class)

    described_class.new.perform("alice", "Title", "Body", { "reason" => "broadcast" })

    expect(NewsmastMastodon::CrossInstancePushService).to have_received(:new)
    expect(service).to have_received(:call).with("alice", "Title", "Body", { "reason" => "broadcast" })
  end
end
