# frozen_string_literal: true

namespace :newsmast_mastodon do
  desc "Re-run newsmast_mastodon's migrations (repairs databases created from db/schema.rb with an older gem version)"
  task repair_migrations: :environment do
    NewsmastMastodon::SchemaLoadMigrations.run!(ActiveRecord::Base.connection_db_config)
    puts "newsmast_mastodon migrations have been run."
  end
end
