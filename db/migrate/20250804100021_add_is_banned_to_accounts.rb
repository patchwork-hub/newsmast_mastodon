# frozen_string_literal: true

class AddIsBannedToAccounts < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:accounts, :is_banned)
      add_column :accounts, :is_banned, :boolean, default: false
    end
  end
end
