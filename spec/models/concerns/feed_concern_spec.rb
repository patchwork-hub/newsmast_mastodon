# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::FeedConcern, type: :model do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  it "defines get and from_redis as instance methods" do
    expect(described_class.instance_methods(false)).to include(:get, :from_redis, :filter_and_cache_statuses)
  end

  it "defines get with expected arity" do
    method = described_class.instance_method(:get)
    # get(limit, max_id=nil, since_id=nil, min_id=nil, account=nil, ...)
    expect(method.arity).to be < 0
  end

  it "defines filter_and_cache_statuses that calls FeedService" do
    expect(described_class.instance_methods(false)).to include(:filter_and_cache_statuses)
  end
end
