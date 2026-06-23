# frozen_string_literal: true

class CreateDraftedStatuses < ActiveRecord::Migration[7.0]
  def change
    create_table :patchwork_drafted_statuses, if_not_exists: true do |t|
      t.belongs_to :account, foreign_key: { on_delete: :cascade }
      t.jsonb :params
      t.timestamps
    end
  end
end
