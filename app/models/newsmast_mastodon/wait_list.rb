# frozen_string_literal: true

module NewsmastMastodon
  class WaitList < ApplicationRecord
    self.table_name = "patchwork_wait_lists"

    belongs_to :account, foreign_key: "account_id", optional: true

    enum :channel_type, { channel: 0, hub: 1 }

    validates :account_id, uniqueness: true, allow_nil: true
    validates :invitation_code, presence: true, uniqueness: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
    validates :description, length: { maximum: 255 }, allow_blank: true

    def generate_invitation_code
      loop do
        self.invitation_code = SecureRandom.random_number(100_000..999_999).to_s
        break unless self.class.exists?(invitation_code: invitation_code)
      end
    end
  end
end
