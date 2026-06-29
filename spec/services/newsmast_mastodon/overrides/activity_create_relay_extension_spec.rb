# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::Overrides::ActivityCreateRelayExtension, type: :service do
  let(:parent_class) do
    Class.new do
      def create_status
        @status
      end
    end
  end

  let(:service_class) do
    Class.new(parent_class) do
      prepend NewsmastMastodon::Overrides::ActivityCreateRelayExtension

      def initialize(status, options = {})
        @status = status
        @options = options
      end

      def with_redis
        yield self
      end

      def zadd(key, score, value)
        true
      end

      def zremrangebyrank(key, start, stop)
        true
      end

      def expire(key, seconds)
        true
      end

      def zcard(key)
        1
      end
    end
  end

  let(:account) { instance_double("Account", domain: "custom.org") }
  let(:status) { instance_double("Status", id: 123, account: account) }

  before do
    allow(NewsmastMastodon::CustomRelayConfig).to receive(:domains).and_return(["custom.org", "relay.net"])
    allow(NewsmastMastodon::RelayFeed).to receive(:timeline_key).and_return("feed:relay:key")
  end

  describe "#create_status" do
    it "adds status to feed if author domain is in CUSTOM_RELAY_DOMAINS" do
      service = service_class.new(status)
      allow(service).to receive(:relay_status?).and_return(false)
      expect(service).to receive(:add_to_relay_feed).with("custom.org")

      service.send(:create_status)
    end

    it "adds status to feed if relay_status? is true" do
      other_account = instance_double("Account", domain: "other.org")
      other_status = instance_double("Status", id: 123, account: other_account)
      relay_actor = instance_double("Account", inbox_url: "https://relay.net/inbox")

      service = service_class.new(other_status, relayed_through_actor: relay_actor)
      allow(service).to receive(:relay_status?).and_return(true)
      allow(NewsmastMastodon::CustomRelayConfig).to receive(:domain_from_inbox_url).with("https://relay.net/inbox").and_return("relay.net")
      expect(service).to receive(:add_to_relay_feed).with("relay.net")

      service.send(:create_status)
    end

    it "adds status to both feeds if both conditions are met" do
      relay_actor = instance_double("Account", inbox_url: "https://relay.net/inbox")

      service = service_class.new(status, relayed_through_actor: relay_actor)
      allow(service).to receive(:relay_status?).and_return(true)
      allow(NewsmastMastodon::CustomRelayConfig).to receive(:domain_from_inbox_url).with("https://relay.net/inbox").and_return("relay.net")
      expect(service).to receive(:add_to_relay_feed).with("custom.org")
      expect(service).to receive(:add_to_relay_feed).with("relay.net")

      service.send(:create_status)
    end

    it "does not add status if neither condition is met" do
      other_account = instance_double("Account", domain: "other.org")
      other_status = instance_double("Status", id: 123, account: other_account)

      service = service_class.new(other_status)
      allow(service).to receive(:relay_status?).and_return(false)
      expect(service).not_to receive(:add_to_relay_feed)

      service.send(:create_status)
    end
  end
end
