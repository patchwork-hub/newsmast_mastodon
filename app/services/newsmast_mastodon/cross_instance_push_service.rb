# frozen_string_literal: true

module NewsmastMastodon
  # Delivers a push notification to a local account's registered devices on
  # behalf of a trusted partner instance. See CrossInstancePushController.
  class CrossInstancePushService < BaseService
    def call(username, title, body, data = {})
      account = Account.find_local(username)
      return if account.blank? || !account.local?

      notification_tokens = NewsmastMastodon::NotificationToken.where(account_id: account.id)
      return if notification_tokens.empty? || notification_tokens.any?(&:mute)

      app_title = ENV["NOTIFICATION_SENDER_NAME"] || "Development Patchwork"
      push_data = { noti_type: "cross_instance_broadcast" }.merge(data.symbolize_keys)

      notification_tokens.where.not(platform_type: "huawei").find_each do |token_record|
        NewsmastMastodon::FirebaseNotificationService.send_notification(token_record.notification_token, title.presence || app_title, body, push_data)
      end
    end
  end
end
