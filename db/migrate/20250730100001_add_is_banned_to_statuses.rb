# frozen_string_literal: true

class AddIsBannedToStatuses < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:statuses, :is_banned)
      add_column :statuses, :is_banned, :boolean, default: false
    end
  end
end
