# frozen_string_literal: true

# Idempotent schema bootstrap used by the Postgres subset CI job.
# Keeps the default sqlite test path untouched while enabling a focused
# Postgres-backed spec subset.

connection_check = ActiveRecord::Base.connection.select_value("SELECT 1")
abort("Postgres connectivity check failed") unless connection_check.to_i == 1

ActiveRecord::Schema.verbose = false

ActiveRecord::Schema.define do
  create_table :server_settings, if_not_exists: true do |t|
    t.string :name
    t.string :optional_value
    t.boolean :value
    t.integer :position
    t.bigint :parent_id
    t.datetime :deleted_at
    t.timestamps null: false
  end
  add_index :server_settings, :name, if_not_exists: true
  add_index :server_settings, :parent_id, if_not_exists: true

  create_table :patchwork_wait_lists, if_not_exists: true do |t|
    t.bigint :account_id
    t.string :invitation_code
    t.string :email
    t.string :description
    t.integer :channel_type
    t.timestamps null: false
  end
  add_index :patchwork_wait_lists, :invitation_code, unique: true, if_not_exists: true
  add_index :patchwork_wait_lists, :account_id, unique: true, if_not_exists: true

  create_table :patchwork_settings, if_not_exists: true do |t|
    t.bigint :account_id
    t.integer :app_name
    t.text :settings
    t.timestamps null: false
  end
  add_index :patchwork_settings, [ :account_id, :app_name ], unique: true, if_not_exists: true

  create_table :patchwork_notification_tokens, if_not_exists: true do |t|
    t.bigint :account_id
    t.string :platform_type
    t.string :notification_token
    t.timestamps null: false
  end
  add_index :patchwork_notification_tokens,
            [ :notification_token, :account_id ],
            unique: true,
            if_not_exists: true

  create_table :patchwork_communities, if_not_exists: true do |t|
    t.string :name
    t.integer :visibility
    t.integer :post_visibility
    t.string :channel_type
    t.timestamps null: false
  end
  add_index :patchwork_communities, :name, unique: true, if_not_exists: true
end

puts "Postgres subset schema bootstrap OK"
