# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::CustomNotificationService, type: :service do
  before do
    status_class = Class.new do
      def self.column_names = []
      def self.find_by(*) = nil
    end

    stub_const("Status", status_class)
  end

  def build_notification_tokens_chain(tokens)
    notification_tokens = instance_double("NotificationTokens")
    where_relation = instance_double("NotificationTokensWhere")
    not_relation = instance_double("NotificationTokensNot")

    allow(notification_tokens).to receive(:empty?).and_return(tokens.empty?)
    allow(notification_tokens).to receive(:any?) { |&blk| tokens.any?(&blk) }
    allow(notification_tokens).to receive(:where).and_return(where_relation)
    allow(where_relation).to receive(:not).with(platform_type: "huawei").and_return(not_relation)
    allow(not_relation).to receive(:pluck).with(:notification_token).and_return(tokens.map(&:notification_token))

    notification_tokens
  end

  it "routes by notification type (mention, reblog, follow, ...)" do
    token = instance_double("NotificationToken", notification_token: "tok-1", mute: false)
    token_chain = build_notification_tokens_chain([ token ])

    notification_token_class = Class.new do
      def self.where(*); end
    end
    stub_const("NewsmastMastodon::NotificationToken", notification_token_class)
    allow(NewsmastMastodon::NotificationToken).to receive(:where).with(account_id: 5).and_return(token_chain)

    account_class = Class.new do
      def self.find(*); end
    end
    stub_const("Account", account_class)
    allow(Account).to receive(:find).with(9).and_return(instance_double("Account", username: "alice"))

    allow(I18n).to receive(:t).and_call_original
    allow(I18n).to receive(:t).with("notification_mailer.follow.subject", name: "alice").and_return("Alice followed you")

    allow(NewsmastMastodon::FirebaseNotificationService).to receive(:send_notification)

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NOTIFICATION_SENDER_NAME").and_return("Patchwork")

    recipient = instance_double("Recipient", id: 5)
    notification = instance_double("Notification", type: :follow, from_account_id: 9, activity_id: 42, account_id: 5)

    described_class.new.call(recipient, notification)

    expect(NewsmastMastodon::FirebaseNotificationService).to have_received(:send_notification)
  end

  it "selects device tokens from NotificationToken" do
    token = instance_double("NotificationToken", notification_token: "tok-2", mute: false)
    token_chain = build_notification_tokens_chain([ token ])

    notification_token_class = Class.new do
      def self.where(*); end
    end
    stub_const("NewsmastMastodon::NotificationToken", notification_token_class)
    allow(NewsmastMastodon::NotificationToken).to receive(:where).with(account_id: 77).and_return(token_chain)

    account_class = Class.new do
      def self.find(*); end
    end
    stub_const("Account", account_class)
    allow(Account).to receive(:find).with(9).and_return(instance_double("Account", username: "alice"))

    allow(I18n).to receive(:t).and_return("body")
    allow(NewsmastMastodon::FirebaseNotificationService).to receive(:send_notification)

    recipient = instance_double("Recipient", id: 77)
    notification = instance_double("Notification", type: :follow, from_account_id: 9, activity_id: 10, account_id: 77)

    described_class.new.call(recipient, notification)

    expect(NewsmastMastodon::NotificationToken).to have_received(:where).with(account_id: 77)
  end

  it "delivers via FirebaseNotificationService with correct payload" do
    token = instance_double("NotificationToken", notification_token: "device-1", mute: false)
    token_chain = build_notification_tokens_chain([ token ])

    notification_token_class = Class.new do
      def self.where(*); end
    end
    stub_const("NewsmastMastodon::NotificationToken", notification_token_class)
    allow(NewsmastMastodon::NotificationToken).to receive(:where).with(account_id: 2).and_return(token_chain)

    account_class = Class.new do
      def self.find(*); end
    end
    stub_const("Account", account_class)
    allow(Account).to receive(:find).with(3).and_return(instance_double("Account", username: "bob"))

    allow(I18n).to receive(:t).with("notification_mailer.follow.subject", name: "bob").and_return("Bob followed you")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NOTIFICATION_SENDER_NAME").and_return("Patchwork App")

    allow(NewsmastMastodon::FirebaseNotificationService).to receive(:send_notification)

    recipient = instance_double("Recipient", id: 2)
    notification = instance_double("Notification", type: :follow, from_account_id: 3, activity_id: 9, account_id: 2)

    described_class.new.call(recipient, notification)

    expect(NewsmastMastodon::FirebaseNotificationService).to have_received(:send_notification).with(
      "device-1",
      "Patchwork App",
      "Bob followed you",
      hash_including(noti_type: :follow, destination_id: "3")
    )
  end

  it "handles admin.sign_up notification type and sends notification" do
    token = instance_double("NotificationToken", notification_token: "admin-tok", mute: false)
    token_chain = build_notification_tokens_chain([ token ])

    notification_token_class = Class.new { def self.where(*); end }
    stub_const("NewsmastMastodon::NotificationToken", notification_token_class)
    allow(NewsmastMastodon::NotificationToken).to receive(:where).with(account_id: 1).and_return(token_chain)

    account_class = Class.new { def self.find(*); end }
    stub_const("Account", account_class)
    allow(Account).to receive(:find).with(10).and_return(instance_double("Account", username: "newuser"))

    allow(I18n).to receive(:t).and_call_original
    allow(I18n).to receive(:t).with("notification_mailer.admin.sign_up.subject", name: "newuser").and_return("New user signed up")
    allow(NewsmastMastodon::FirebaseNotificationService).to receive(:send_notification)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NOTIFICATION_SENDER_NAME").and_return("Patchwork")

    recipient = instance_double("Recipient", id: 1)
    notification = instance_double("Notification", type: :'admin.sign_up', from_account_id: 10, activity_id: 10, account_id: 1)

    described_class.new.call(recipient, notification)

    expect(NewsmastMastodon::FirebaseNotificationService).to have_received(:send_notification).with(
      "admin-tok",
      "Patchwork",
      "New user signed up",
      hash_including(noti_type: :'admin.sign_up')
    )
  end

  it "handles admin.report notification type and sends notification" do
    token = instance_double("NotificationToken", notification_token: "admin-tok-2", mute: false)
    token_chain = build_notification_tokens_chain([ token ])

    notification_token_class = Class.new { def self.where(*); end }
    stub_const("NewsmastMastodon::NotificationToken", notification_token_class)
    allow(NewsmastMastodon::NotificationToken).to receive(:where).with(account_id: 2).and_return(token_chain)

    account_class = Class.new { def self.find(*); end }
    stub_const("Account", account_class)
    allow(Account).to receive(:find).with(11).and_return(instance_double("Account", username: "reporter"))

    allow(I18n).to receive(:t).and_call_original
    allow(I18n).to receive(:t).with("notification_mailer.admin.report.subject", name: "reporter").and_return("New report filed")
    allow(NewsmastMastodon::FirebaseNotificationService).to receive(:send_notification)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NOTIFICATION_SENDER_NAME").and_return("Patchwork")

    recipient = instance_double("Recipient", id: 2)
    notification = instance_double("Notification", type: :'admin.report', from_account_id: 11, activity_id: 99, account_id: 2)

    described_class.new.call(recipient, notification)

    expect(NewsmastMastodon::FirebaseNotificationService).to have_received(:send_notification).with(
      "admin-tok-2",
      "Patchwork",
      "New report filed",
      hash_including(noti_type: :'admin.report', destination_id: "99")
    )
  end

  it "returns nil and logs a warning for unknown notification types" do
    token = instance_double("NotificationToken", notification_token: "tok-x", mute: false)
    token_chain = build_notification_tokens_chain([ token ])

    notification_token_class = Class.new { def self.where(*); end }
    stub_const("NewsmastMastodon::NotificationToken", notification_token_class)
    allow(NewsmastMastodon::NotificationToken).to receive(:where).with(account_id: 3).and_return(token_chain)

    account_class = Class.new { def self.find(*); end }
    stub_const("Account", account_class)
    allow(Account).to receive(:find).with(12).and_return(instance_double("Account", username: "unknown"))

    allow(Rails.logger).to receive(:warn)
    allow(NewsmastMastodon::FirebaseNotificationService).to receive(:send_notification)

    recipient = instance_double("Recipient", id: 3)
    notification = instance_double("Notification", type: :some_unknown_type, from_account_id: 12, activity_id: 5, account_id: 3)

    result = described_class.new.call(recipient, notification)

    expect(result).to be_nil
    expect(NewsmastMastodon::FirebaseNotificationService).not_to have_received(:send_notification)
    expect(Rails.logger).to have_received(:warn).with(/Unhandled notification type/)
  end
end
