# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class OptimizeNullIndexMediaAttachmentsDraftedStatusId < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def up
    update_index :media_attachments, 'index_media_attachments_on_patchwork_drafted_status_id', :patchwork_drafted_status_id, where: 'patchwork_drafted_status_id IS NOT NULL'
  end

  def down
    update_index :media_attachments, 'index_media_attachments_on_patchwork_drafted_status_id', :patchwork_drafted_status_id
  end
end
