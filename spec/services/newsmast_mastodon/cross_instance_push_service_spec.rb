# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::CrossInstancePushService, type: :service do
  it "does nothing when the account does not exist locally" do
    account_class = Class.new do
      def self.find_local(*) = nil
    end
    stub_const("Account", account_class)

    expect(NewsmastMastodon::FirebaseNotificationService).not_to receive(:send_notification)

    described_class.new.call("missing_user", "Title", "Body", {})
  end

  it "does nothing when the account is not local" do
    account_class = Class.new do
      def self.find_local(*); end
    end
    stub_const("Account", account_class)
    allow(Account).to receive(:find_local).and_return(instance_double("Account", id: 1, local?: false))

    expect(NewsmastMastodon::FirebaseNotificationService).not_to receive(:send_notification)

    described_class.new.call("remote_user", "Title", "Body", {})
  end

  it "skips delivery when any registered token is muted" do
    account_class = Class.new do
      def self.find_local(*); end
    end
    stub_const("Account", account_class)
    allow(Account).to receive(:find_local).and_return(instance_double("Account", id: 5, local?: true))

    token = instance_double("NotificationToken", mute: true)
    notification_tokens = instance_double("NotificationTokens", empty?: false, any?: true)

    notification_token_class = Class.new do
      def self.where(*); end
    end
    stub_const("NewsmastMastodon::NotificationToken", notification_token_class)
    allow(NewsmastMastodon::NotificationToken).to receive(:where).with(account_id: 5).and_return(notification_tokens)
    allow(notification_tokens).to receive(:any?) { |&blk| [ token ].any?(&blk) }

    expect(NewsmastMastodon::FirebaseNotificationService).not_to receive(:send_notification)

    described_class.new.call("alice", "Title", "Body", {})
  end

  it "sends a push to every registered non-huawei device" do
    account_class = Class.new do
      def self.find_local(*); end
    end
    stub_const("Account", account_class)
    allow(Account).to receive(:find_local).and_return(instance_double("Account", id: 5, local?: true))

    token = instance_double("NotificationToken", notification_token: "tok-1", mute: false)

    where_relation = instance_double("WhereRelation")
    final_relation = instance_double("FinalRelation")
    notification_tokens = instance_double("NotificationTokens", empty?: false)

    notification_token_class = Class.new do
      def self.where(*); end
    end
    stub_const("NewsmastMastodon::NotificationToken", notification_token_class)
    allow(NewsmastMastodon::NotificationToken).to receive(:where).with(account_id: 5).and_return(notification_tokens)
    allow(notification_tokens).to receive(:any?) { |&blk| [ token ].any?(&blk) }
    allow(notification_tokens).to receive(:where).and_return(where_relation)
    allow(where_relation).to receive(:not).with(platform_type: "huawei").and_return(final_relation)
    allow(final_relation).to receive(:find_each).and_yield(token)

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NOTIFICATION_SENDER_NAME").and_return("Patchwork")

    allow(NewsmastMastodon::FirebaseNotificationService).to receive(:send_notification)

    described_class.new.call("alice", "Title", "Body", { "reason" => "broadcast" })

    expect(NewsmastMastodon::FirebaseNotificationService).to have_received(:send_notification).with(
      "tok-1", "Title", "Body", hash_including(noti_type: "cross_instance_broadcast", reason: "broadcast")
    )
  end
end
