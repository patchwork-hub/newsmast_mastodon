# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::CustomFeed, type: :model do
  let(:account) { instance_double("Account", chosen_languages: nil) }

  it "accepts account and options on initialize" do
    feed = described_class.new(account)
    expect(feed).to be_a(described_class)
  end

  it "exposes #get method" do
    expect(described_class.instance_method(:get)).not_to be_nil
  end

  it "respects with_replies? option" do
    feed = described_class.new(account, with_replies: true)
    expect(feed.send(:with_replies?)).to be true
  end

  it "respects with_reblogs? option" do
    feed = described_class.new(account, with_reblogs: true)
    expect(feed.send(:with_reblogs?)).to be true
  end
end
