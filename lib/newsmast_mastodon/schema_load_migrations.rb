# frozen_string_literal: true

require "zlib"

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

        # Hold Rails' migration lock from removing the versions until the
        # migrations have run, so a concurrent repair or db:migrate can't
        # remove versions this run has just restored. context.migrate takes the
        # same lock again on the same connection, which advisory locks allow.
        with_migration_lock(ActiveRecord::Tasks::DatabaseTasks.migration_connection) do
          recorded = pool.schema_migration.versions & versions.map(&:to_s)
          recorded.each { |version| pool.schema_migration.delete_version(version) }

          context.migrate
        end
      end

      # The advisory lock ActiveRecord::Migrator takes for this database
      # (see Migrator#generate_migrator_advisory_lock_id).
      def migration_lock_id(connection)
        ActiveRecord::Migrator::MIGRATOR_SALT * Zlib.crc32(connection.current_database)
      end

      # The gem's migration directories, but only when the host app actually
      # runs them: the engine appends them to the app's db/migrate paths, and
      # the app must be Mastodon. The gem's own dummy app also gets the paths
      # appended, but the migrations need Mastodon (lib/mastodon/migration_helpers),
      # so replaying them there would fail.
      def migration_paths
        return [] unless mastodon_host?

        engine_paths = NewsmastMastodon::Engine.paths["db/migrate"].existent
        app_paths = Rails.application.config.paths["db/migrate"].expanded

        engine_paths & app_paths
      end

      def mastodon_host?
        Rails.root.join("lib", "mastodon", "migration_helpers.rb").file?
      end

      private

      def with_migration_lock(connection)
        return yield unless connection.advisory_locks_enabled?

        lock_id = migration_lock_id(connection)
        raise ActiveRecord::ConcurrentMigrationError unless connection.get_advisory_lock(lock_id)

        begin
          yield
        ensure
          unless connection.release_advisory_lock(lock_id)
            raise ActiveRecord::ConcurrentMigrationError, ActiveRecord::ConcurrentMigrationError::RELEASE_LOCK_FAILED_MESSAGE
          end
        end
      end

      def primary?(db_config)
        return true unless db_config.respond_to?(:name)

        db_config.name.to_s == "primary"
      end
    end
  end
end
