# frozen_string_literal: true


module NewsmastMastodon
  class CustomNotificationService < BaseService
    include NonChannelHelper

    def call(recipient, notification)
      notification_tokens = NewsmastMastodon::NotificationToken.where(account_id: recipient.id)
      return nil if notification_tokens.empty? || notification_tokens.any? { |token| token.mute }

      body = ""
      destination_id = 0
      reblogged_id = 0
      visibility = ""
      notification_request = nil
      notification_type = notification.type&.to_sym
      from_account_username = Account.find(notification.from_account_id).username

      # To skip sending notification when the status is reblogged by the Group channels and local_only is true
      return nil if skip_local_only_notify?(notification)

      case notification_type
      when :status
        body = I18n.t("notification_mailer.status.subject", name: from_account_username)
        destination_id = Status.find(notification.activity_id).id
      when :update
        body = I18n.t("notification_mailer.update.subject", name: from_account_username)
        destination_id = Status.find(notification.activity_id).id
      when :reblog
        body = I18n.t("notification_mailer.reblog.subject", name: from_account_username)
        status = Status.find(notification.activity_id)
        destination_id = status.id
        reblogged_id = status.reblog_of_id
      when :favourite
        body = I18n.t("notification_mailer.favourite.subject", name: from_account_username)
        favourite = Favourite.find(notification.activity_id)
        destination_id = Status.find(favourite.status_id).id
      when :mention
        mention = Mention.find(notification.activity_id)
        status = Status.find(mention.status_id)
        notification_request = NotificationRequest.find_by(account_id: notification.account_id)
        body = if notification_request.present?
                 I18n.t("notification.mention.conversation_request")
        elsif status.visibility == Status.visibilities[:direct]
                 I18n.t("notification.mention.direct_message", name: from_account_username)
        else
                 I18n.t("notification_mailer.mention.subject", name: from_account_username)
        end
        destination_id = status.id
        visibility = status.visibility
      when :poll
        poll = Poll.find(notification.activity_id)
        body = notification.from_account_id == poll.account_id ? I18n.t("notification.poll.ended_you") : I18n.t("notification.poll.ended_voted")
        destination_id = Status.find(poll.status_id).id
      when :follow
        body = I18n.t("notification_mailer.follow.subject", name: from_account_username)
        destination_id = notification.from_account_id
      when :follow_request
        body = I18n.t("notification_mailer.follow_request.subject", name: from_account_username)
        destination_id = notification.from_account_id
      when :quote
        body = I18n.t("notification_mailer.quote.subject", name: from_account_username)
        destination_id = Quote.find(notification.activity_id)&.status_id
      when :quoted_update
        body = I18n.t("notification_mailer.update.subject", name: from_account_username)
        destination_id = Quote.find(notification.activity_id)&.status_id
      when :'admin.sign_up'
        return nil if ENV["SKIP_SIGNUP_PUSH_NOTI"].present? && ENV["SKIP_SIGNUP_PUSH_NOTI"] == "true"
        body = I18n.t("notification_mailer.admin.sign_up.subject", name: from_account_username)
        destination_id = notification.from_account_id
      when :'admin.report'
        body = I18n.t("notification_mailer.admin.report.subject", name: from_account_username)
        destination_id = notification.activity_id
      else
        Rails.logger.warn "[CustomNotificationService] Unhandled notification type: #{notification.type}"
        return nil
      end

      return nil if body.blank?

      data = {
        noti_type: notification_type,
        destination_id: destination_id.to_s,
        reblogged_id: reblogged_id.to_s,
        visibility: visibility
      }
      data.merge!(conversation_request: "true") if notification_request.present?

      # ios & android
      ios_android_devices = notification_tokens.where.not(platform_type: "huawei").pluck(:notification_token)

      app_title = ENV["NOTIFICATION_SENDER_NAME"] || "Development Patchwork"

      ios_android_devices.each do |device|
        NewsmastMastodon::FirebaseNotificationService.send_notification(device, app_title, body, data)
      end
    end

    private

    def skip_local_only_notify?(notification)
      return false unless Status.column_names.include?("local_only")

      notification.type == :reblog && Status.find_by(id: notification.activity_id)&.local_only == true
    end
  end
end
