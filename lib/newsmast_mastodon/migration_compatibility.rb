# frozen_string_literal: true

module NewsmastMastodon
  module MigrationCompatibility
    TARGET_COLUMN_TABLE = :media_attachments
    TARGET_COLUMN = :thumbnail_storage_schema_version
    TARGET_NEW_TABLES = %i[collections collection_items].freeze

    def add_column(table_name, column_name, type, **options)
      if suppress_thumbnail_schema_version_duplicate?(table_name, column_name)
        return if connection.column_exists?(TARGET_COLUMN_TABLE, TARGET_COLUMN)
      end

      super
    rescue ActiveRecord::StatementInvalid => e
      raise unless suppress_thumbnail_schema_version_duplicate?(table_name, column_name)
      raise unless duplicate_column_error?(e)

      # A concurrent process may have created the column after the pre-check.
      return if connection.column_exists?(TARGET_COLUMN_TABLE, TARGET_COLUMN)

      raise
    end

    def create_table(table_name, **options, &block)
      if suppress_table_duplicate?(table_name)
        return if connection.table_exists?(table_name)
      end

      super
    rescue ActiveRecord::StatementInvalid => e
      raise unless suppress_table_duplicate?(table_name)
      raise unless duplicate_table_error?(e)

      # A concurrent process may have created the table after the pre-check.
      return if connection.table_exists?(table_name)

      raise
    end

    private

    def suppress_thumbnail_schema_version_duplicate?(table_name, column_name)
      table_name.to_sym == TARGET_COLUMN_TABLE && column_name.to_sym == TARGET_COLUMN
    end

    def suppress_table_duplicate?(table_name)
      TARGET_NEW_TABLES.include?(table_name.to_sym)
    end

    def duplicate_column_error?(error)
      cause = error.cause
      return true if defined?(PG::DuplicateColumn) && cause.is_a?(PG::DuplicateColumn)

      error.message.include?("PG::DuplicateColumn")
    end

    def duplicate_table_error?(error)
      cause = error.cause
      return true if defined?(PG::DuplicateTable) && cause.is_a?(PG::DuplicateTable)

      error.message.include?("PG::DuplicateTable")
    end
  end
end