# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "newsmast_mastodon:relay_feed:backfill" do
  let(:task) { Rake::Task["newsmast_mastodon:relay_feed:backfill"] }
  let(:redis) { double("Redis", zremrangebyrank: true, expire: true, zcard: 2) }
  let(:status_scope) { double("Status scope") }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("newsmast_mastodon:relay_feed:backfill")
    task.reenable

    fake_redis = redis
    stub_const("Redisable", Module.new { define_method(:redis) { fake_redis } })
    allow(NewsmastMastodon::CustomRelayConfig).to receive(:domains).and_return([ "mastodon.social" ])

    account_class = Class.new { def self.where(*) = nil }
    allow(account_class).to receive(:where).with(domain: "mastodon.social").and_return(double(select: :account_ids))
    stub_const("Account", account_class)

    status_class = Class.new { def self.where(*) = nil }
    allow(status_class).to receive(:where).with(account_id: :account_ids).and_return(status_scope)
    allow(status_scope).to receive_messages(where: status_scope, order: status_scope, limit: status_scope, pluck: [ 20, 10 ])
    stub_const("Status", status_class)

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOMAINS", "").and_return("")
  end

  it "writes existing status ids into the domain's relay feed key when DRY_RUN=false" do
    allow(ENV).to receive(:fetch).with("DRY_RUN", "true").and_return("false")

    expect(status_scope).to receive(:limit).with(800).and_return(status_scope)
    expect(redis).to receive(:zadd).with("feed:relay:mastodon-social", [ [ 20, 20 ], [ 10, 10 ] ])
    expect(redis).to receive(:zremrangebyrank).with("feed:relay:mastodon-social", 0, -801)
    expect(redis).to receive(:expire).with("feed:relay:mastodon-social", 30.days.to_i)

    expect { task.invoke }.to output(/added 2 statuses/).to_stdout
  end

  it "does not write to redis in dry run" do
    allow(ENV).to receive(:fetch).with("DRY_RUN", "true").and_return("true")

    expect(redis).not_to receive(:zadd)

    expect { task.invoke }.to output(/would add 2 statuses/).to_stdout
  end
end
