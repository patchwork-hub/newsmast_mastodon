# frozen_string_literal: true

module NewsmastMastodon
  module Concerns
    module EmailNotificationAttributesConcern
      extend ActiveSupport::Concern

      def email_notification_attributes(enabled: false)
        {
          "always_send_emails"                   => enabled,
          "notification_emails.follow"           => enabled,
          "notification_emails.reblog"           => enabled,
          "notification_emails.favourite"        => enabled,
          "notification_emails.mention"          => enabled,
          "notification_emails.follow_request"   => enabled,
          "notification_emails.report"           => enabled,
          "notification_emails.pending_account"  => enabled,
          "notification_emails.trends"           => enabled,
          "notification_emails.appeal"           => enabled,
          "notification_emails.quote"            => enabled,
          "notification_emails.software_updates" => enabled ? "critical" : "none"
        }
      end
    end
  end
end
