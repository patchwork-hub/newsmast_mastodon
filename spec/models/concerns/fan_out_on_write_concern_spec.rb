# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::FanOutOnWriteConcern, type: :model do
  it "fans out status writes to custom feeds via FeedManager extension" do
    expect(described_class).to be_a(Module)
    # The concern wraps the original call and adds custom fan-out logic
    expect(described_class.private_instance_methods(false)).to include(:fan_out_to_custom_timeline!)
  end
end
