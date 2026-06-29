class CreatePatchworkNotificationTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_notification_tokens, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: { to_table: :accounts, on_delete: :cascade, validate: false }
      t.string :notification_token
      t.string :platform_type
      t.boolean :mute, null: false, default: false
      t.timestamps
    end
  end
end
