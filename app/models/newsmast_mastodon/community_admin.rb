# frozen_string_literal: true

module NewsmastMastodon
  class CommunityAdmin < ApplicationRecord
    self.table_name = "patchwork_communities_admins"

    ROLES = %w[OrganisationAdmin UserAdmin HubAdmin NewsmastAdmin GroupAdmin GroupModerator].freeze
    GROUP_ROLES = %w[GroupAdmin GroupModerator].freeze

    belongs_to :community, foreign_key: "patchwork_community_id", optional: true, class_name: "NewsmastMastodon::Community"
    belongs_to :account, foreign_key: "account_id", optional: true

    enum :account_status, active: 0, suspended: 1, deleted: 2

    validates :role, inclusion: { in: ROLES, message: "%{value} is not a valid role" }, allow_blank: true

    scope :active_group_roles, -> {
      where(account_status: account_statuses[:active], role: GROUP_ROLES)
    }
  end
end
