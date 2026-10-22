# frozen_string_literal: true

module NewsmastMastodon
  class AutoFollow < ApplicationRecord
    self.table_name = "patchwork_auto_follows"

    has_many :auto_follow_accounts, -> { order(:position, :id) },
             class_name: "NewsmastMastodon::AutoFollowAccount",
             foreign_key: "patchwork_auto_follow_id",
             dependent: :delete_all
  end
end