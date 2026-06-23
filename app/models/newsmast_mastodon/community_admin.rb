# frozen_string_literal: true

module NewsmastMastodon
  class CommunityAdmin < ApplicationRecord
    self.table_name = "patchwork_communities_admins"

    belongs_to :community, foreign_key: "patchwork_community_id", optional: true, class_name: "NewsmastMastodon::Community"
    belongs_to :account, foreign_key: "account_id", optional: true

    enum :account_status, active: 0, suspended: 1, deleted: 2
  end
end
