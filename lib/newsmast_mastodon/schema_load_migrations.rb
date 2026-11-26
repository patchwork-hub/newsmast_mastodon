# frozen_string_literal: true

module NewsmastMastodon
  # Runs this gem's migrations right after a database is built from the host's
  # schema file.
  #
  # The gem appends its migrations to the host's migration paths. When a fresh
  # database is created from db/schema.rb (db:setup, db:prepare, db:schema:load,
  # db:reset, or the test schema check), Rails records every migration older
  # than the schema's version as already run. On upstream Mastodon that
  # includes most of this gem's migrations, so their tables and columns would
  # never be created.
  #
  # After the schema is loaded, this removes the gem's versions from
  # schema_migrations and runs the gem's migrations, which are written to be
  # safe to re-run (if_not_exists / column_exists? guards). Databases upgraded
  # with db:migrate are unaffected, because that path never loads the schema.
  #
  # Set NEWSMAST_SKIP_SCHEMA_LOAD_MIGRATIONS=1 to turn this off.
  module SchemaLoadMigrations
    def load_schema(db_config, *args, **kwargs)
      result = super
      NewsmastMastodon::SchemaLoadMigrations.run!(db_config)
      result
    end

    class << self
      def install!
        require "active_record/tasks/database_tasks"

        tasks = ActiveRecord::Tasks::DatabaseTasks.singleton_class
        tasks.prepend(self) unless tasks.ancestors.include?(self)
      end

      def run!(db_config)
        return if ENV["NEWSMAST_SKIP_SCHEMA_LOAD_MIGRATIONS"] == "1"
        return unless primary?(db_config)

        paths = migration_paths
        return if paths.empty?

        pool = ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool
        context = ActiveRecord::MigrationContext.new(paths, pool.schema_migration, pool.internal_metadata)
        versions = context.migrations.map(&:version)
        return if versions.empty?

        recorded = pool.schema_migration.versions & versions.map(&:to_s)
        recorded.each { |version| pool.schema_migration.delete_version(version) }

        context.migrate
      end

      # The gem's migration directories, but only when the host app actually
      # runs them (they are appended to the app's db/migrate paths by the
      # engine, which isn't the case inside the gem's own dummy app).
      def migration_paths
        engine_paths = NewsmastMastodon::Engine.paths["db/migrate"].existent
        app_paths = Rails.application.config.paths["db/migrate"].expanded

        engine_paths & app_paths
      end

      private

      def primary?(db_config)
        return true unless db_config.respond_to?(:name)

        db_config.name.to_s == "primary"
      end
    end
  end
end
