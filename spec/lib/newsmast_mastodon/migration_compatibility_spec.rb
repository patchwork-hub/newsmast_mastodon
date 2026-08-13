# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::MigrationCompatibility do
  TARGET_COLUMN_TABLE = :media_attachments
  TARGET_COLUMN = :thumbnail_storage_schema_version
  NON_TARGET_COLUMN = :newsmast_mastodon_compatibility_probe
  TARGET_NEW_TABLES = %i[collections collection_items].freeze
  NON_TARGET_TABLE = :newsmast_mastodon_compatibility_probe_table

  let(:migration_class) do
    Class.new(ActiveRecord::Migration[8.0]) do
      def version
        1
      end
    end
  end

  let(:migration) { migration_class.new }
  let(:connection) { ActiveRecord::Base.connection }

  around do |example|
    created_table = false
    created_target_column = false

    unless connection.table_exists?(TARGET_COLUMN_TABLE)
      connection.create_table(TARGET_COLUMN_TABLE) { |t| t.timestamps null: true }
      created_table = true
    end

    unless connection.column_exists?(TARGET_COLUMN_TABLE, TARGET_COLUMN)
      connection.add_column(TARGET_COLUMN_TABLE, TARGET_COLUMN, :integer)
      created_target_column = true
    end

    TARGET_NEW_TABLES.each do |table_name|
      connection.create_table(table_name) { |t| t.timestamps null: true } unless connection.table_exists?(table_name)
    end

    example.run
  ensure
    connection.drop_table(NON_TARGET_TABLE) if connection.table_exists?(NON_TARGET_TABLE)
    TARGET_NEW_TABLES.each do |table_name|
      connection.drop_table(table_name) if connection.table_exists?(table_name)
    end
    connection.remove_column(TARGET_COLUMN_TABLE, NON_TARGET_COLUMN) if connection.column_exists?(TARGET_COLUMN_TABLE, NON_TARGET_COLUMN)
    connection.remove_column(TARGET_COLUMN_TABLE, TARGET_COLUMN) if created_target_column && connection.column_exists?(TARGET_COLUMN_TABLE, TARGET_COLUMN)
    connection.drop_table(TARGET_COLUMN_TABLE) if created_table && connection.table_exists?(TARGET_COLUMN_TABLE)
  end

  before do
    migration_class.prepend(described_class)
  end

  it "no-ops when thumbnail_storage_schema_version already exists" do
    expect do
      migration.add_column(TARGET_COLUMN_TABLE, TARGET_COLUMN, :integer)
    end.not_to raise_error
  end

  it "raises duplicate errors for non-target columns" do
    connection.add_column(TARGET_COLUMN_TABLE, NON_TARGET_COLUMN, :integer) unless connection.column_exists?(TARGET_COLUMN_TABLE, NON_TARGET_COLUMN)

    expect do
      migration.add_column(TARGET_COLUMN_TABLE, NON_TARGET_COLUMN, :integer)
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  TARGET_NEW_TABLES.each do |table_name|
    it "no-ops when #{table_name} already exists" do
      expect do
        migration.create_table(table_name) { |t| t.timestamps null: true }
      end.not_to raise_error
    end
  end

  it "raises duplicate errors for non-target tables" do
    connection.create_table(NON_TARGET_TABLE) { |t| t.timestamps null: true } unless connection.table_exists?(NON_TARGET_TABLE)

    expect do
      migration.create_table(NON_TARGET_TABLE) { |t| t.timestamps null: true }
    end.to raise_error(ActiveRecord::StatementInvalid)
  end
end