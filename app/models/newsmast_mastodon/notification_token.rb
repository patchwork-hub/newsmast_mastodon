# frozen_string_literal: true

module NewsmastMastodon
  class NotificationToken < ApplicationRecord
    self.table_name = "patchwork_notification_tokens"

    belongs_to :account

    validates :platform_type, presence: true
    validates :notification_token, presence: true, uniqueness: { scope: :account_id }
  end
end
