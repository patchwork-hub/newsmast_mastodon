# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "newsmast_mastodon:remove_csid_badge_fields" do
  let(:task) { Rake::Task["newsmast_mastodon:remove_csid_badge_fields"] }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("newsmast_mastodon:remove_csid_badge_fields")
    task.reenable
  end

  it "removes only CSID Badge fields and preserves other fields" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DRY_RUN", "true").and_return("false")
    fields = [
      { "name" => "CSID Badge", "value" => "CSIDNet Team" },
      { "name" => "Display name", "value" => "Member" },
      { "name" => "Website", "value" => "https://example.test" }
    ]
    account = double("Account")
    allow(account).to receive(:[]).with(:fields).and_return(fields)
    scope = double("Account scope", count: 1)
    allow(scope).to receive(:find_in_batches).with(batch_size: 200).and_yield([account])
    account_class = Class.new do
      def self.where(*) = nil
    end
    allow(account_class).to receive(:where).with("fields @> ?", [{ name: "CSID Badge" }].to_json).and_return(scope)
    stub_const("Account", account_class)
    expect(account).to receive(:update_columns).with(hash_including(fields: fields.drop(1), updated_at: anything))

    task.invoke
  end
end