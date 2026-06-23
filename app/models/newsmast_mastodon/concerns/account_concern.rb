# frozen_string_literal: true

module NewsmastMastodon
  module Concerns
    module AccountConcern
      extend ActiveSupport::Concern

      included do
        has_many :notification_tokens,
                 class_name: "NewsmastMastodon::NotificationToken",
                 dependent: :delete_all,
                 inverse_of: :account

        has_many :patchwork_settings,
                 class_name: "NewsmastMastodon::PatchworkSetting",
                 foreign_key: :account_id,
                 dependent: :destroy

        has_many :patchwork_drafted_statuses,
                 inverse_of: :account,
                 dependent: :destroy,
                 class_name: "NewsmastMastodon::DraftedStatus"

        # Tag follows (via TagFollow model) — followed tags convenience association.
        has_many :followed_tags, through: :tag_follows, source: :tag

        scope :without_banned,  -> { where(accounts: { is_banned: false }) }
        scope :channel_admins, ->(value) { where(id: value) }

        def excluded_domain_by_server_setting_federation
          user = User.find_by(account_id: id)
          Rails.cache.fetch("filter_account_ids_by_server_setting_federation:#{id}") do
            Account.where(domain: user.get_server_setting_exclude_domains).pluck(:id)
          end
        end

        def follow_account?(target_account_id)
          Follow.exists?(account_id: self&.id, target_account_id: target_account_id)
        end
      end
    end
  end
end
