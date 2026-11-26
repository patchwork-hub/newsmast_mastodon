# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::ReblogChannelsWorker, type: :worker do
  it "performs reblog to community/channel" do
    stub_const("Account", Class.new do
      def self.find_by(*); end
    end)

    allow(Account).to receive(:find_by).with(id: 7).and_return(nil)

    expect(described_class.new.perform(12, 7)).to be(false)
  end

  describe "#fetch_post_url" do
    let(:worker) { described_class.new }

    before do
      account = Struct.new(:pretty_acct).new("alice@remote.example")
      worker.instance_variable_set(:@status, Struct.new(:account, :id).new(account, 42))
    end

    around do |example|
      web_domain_was = Rails.configuration.x.web_domain
      example.run
    ensure
      Rails.configuration.x.web_domain = web_domain_was
    end

    it "uses the web domain when it differs from LOCAL_DOMAIN" do
      Rails.configuration.x.web_domain = "social.example.org"
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("LOCAL_DOMAIN", nil).and_return("example.org")

      expect(worker.send(:fetch_post_url)).to eq("https://social.example.org/@alice@remote.example/42")
    end

    it "falls back to LOCAL_DOMAIN when no web domain is configured" do
      Rails.configuration.x.web_domain = nil
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("WEB_DOMAIN").and_return(nil)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("LOCAL_DOMAIN", nil).and_return("example.org")

      expect(worker.send(:fetch_post_url)).to eq("https://example.org/@alice@remote.example/42")
    end
  end
end
