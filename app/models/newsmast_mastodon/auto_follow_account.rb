# frozen_string_literal: true

module NewsmastMastodon
  class AutoFollowAccount < ApplicationRecord
    self.table_name = "patchwork_auto_follow_accounts"

    belongs_to :auto_follow,
               class_name: "NewsmastMastodon::AutoFollow",
               foreign_key: "patchwork_auto_follow_id"
    belongs_to :account
  end
end