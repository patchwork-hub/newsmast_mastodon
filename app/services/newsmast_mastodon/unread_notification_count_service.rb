# frozen_string_literal: true

module NewsmastMastodon
  # Computes the unread notification count used for the iOS app icon badge.
  #
  # Mirrors Mastodon's GET /api/v2/notifications/unread_count: grouped
  # notifications newer than the user's "notifications" marker (last_read_id),
  # excluding filtered notifications and those from suspended accounts.
  class UnreadNotificationCountService
    LIMIT = 100

    def self.call(account)
      user = account.user
      return nil if user.nil?

      last_read_id = user.markers.find_by(timeline: "notifications")&.last_read_id

      account.notifications
             .without_suspended
             .browserable
             .paginate_groups_by_min_id(LIMIT, min_id: last_read_id)
             .count
    rescue StandardError => e
      Rails.logger.error("[UnreadNotificationCountService] Failed to count unread notifications for account #{account&.id}: #{e.message}")
      nil
    end
  end
end
