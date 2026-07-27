# frozen_string_literal: true

class CreatePatchworkStatusReactions < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_status_reactions, if_not_exists: true do |t|
      t.bigint :account_id, null: false
      t.bigint :status_id,  null: false
      t.string :name,       null: false, default: ''
      t.timestamps
    end

    add_index :patchwork_status_reactions, [ :account_id, :status_id ], unique: true, if_not_exists: true, name: 'index_patchwork_status_reactions_on_account_id_and_status_id'
    add_index :patchwork_status_reactions, :status_id, if_not_exists: true, name: 'index_patchwork_status_reactions_on_status_id'

    add_foreign_key :patchwork_status_reactions, :accounts, on_delete: :cascade, validate: false, if_not_exists: true
    add_foreign_key :patchwork_status_reactions, :statuses, on_delete: :cascade, validate: false, if_not_exists: true
  end
end
