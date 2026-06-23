# frozen_string_literal: true

class AddIsBannedToTags < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:tags, :is_banned)
      add_column :tags, :is_banned, :boolean, default: false
    end
  end
end
