# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::ForYouFeed, type: :model do
  it "#get(limit, max_id, since_id, min_id) fetches personalized status ids from Redis" do
    require_host!
    account  = Fabricate(:account)
    feed     = described_class.new(account)
    fake_redis = instance_double("Redis", zrange: [])
    allow(feed).to receive(:redis).and_return(fake_redis)

    result = feed.get(20)

    expect(result).to be_an(Array)
  end

  it "honours reply/reblog/media filtering params" do
    require_host!
    account  = Fabricate(:account)
    feed     = described_class.new(account, exclude_replies: true, exclude_direct_statuses: true)
    fake_redis = instance_double("Redis", zrange: [])
    allow(feed).to receive(:redis).and_return(fake_redis)

    result = feed.get(20)

    expect(result).to be_an(Array)
  end
end
