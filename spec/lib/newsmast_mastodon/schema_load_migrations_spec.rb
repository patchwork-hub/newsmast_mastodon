# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe NewsmastMastodon::SchemaLoadMigrations do
  let(:version) { "20200101000001" }
  let(:table) { :newsmast_schema_load_probe }
  # Looked up each time: the load_schema example swaps the connection pool.
  def pool = ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool
  def connection = pool.lease_connection
  let(:primary_config) { instance_double(ActiveRecord::DatabaseConfigurations::HashConfig, name: "primary") }

  around do |example|
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "#{version}_create_newsmast_schema_load_probe.rb"), <<~RUBY)
        class CreateNewsmastSchemaLoadProbe < ActiveRecord::Migration[8.0]
          def change
            create_table :#{table}, if_not_exists: true
          end
        end
      RUBY
      @migrations_dir = dir

      verbose_was = ActiveRecord::Migration.verbose
      ActiveRecord::Migration.verbose = false
      example.run
    ensure
      ActiveRecord::Migration.verbose = verbose_was
      connection.drop_table(table, if_exists: true)
      pool.schema_migration.delete_version(version) if pool.schema_migration.table_exists?
    end
  end

  before do
    allow(described_class).to receive(:migration_paths).and_return([ @migrations_dir ])
    pool.schema_migration.create_table
    pool.internal_metadata.create_table
  end

  it "is installed on ActiveRecord::Tasks::DatabaseTasks" do
    expect(ActiveRecord::Tasks::DatabaseTasks.singleton_class.ancestors).to include(described_class)
  end

  it "runs gem migrations that the schema load recorded as already run" do
    # db/schema.rb marks every migration older than its version as run.
    pool.schema_migration.create_version(version)

    described_class.run!(primary_config)

    expect(connection.table_exists?(table)).to be(true)
    expect(pool.schema_migration.versions).to include(version)
  end

  it "runs gem migrations that were not recorded at all" do
    described_class.run!(primary_config)

    expect(connection.table_exists?(table)).to be(true)
    expect(pool.schema_migration.versions).to include(version)
  end

  it "does nothing for databases other than the primary one" do
    pool.schema_migration.create_version(version)

    described_class.run!(instance_double(ActiveRecord::DatabaseConfigurations::HashConfig, name: "replica"))

    expect(connection.table_exists?(table)).to be(false)
  end

  it "does nothing when NEWSMAST_SKIP_SCHEMA_LOAD_MIGRATIONS=1" do
    pool.schema_migration.create_version(version)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NEWSMAST_SKIP_SCHEMA_LOAD_MIGRATIONS").and_return("1")

    described_class.run!(primary_config)

    expect(connection.table_exists?(table)).to be(false)
  end

  it "does nothing when the host doesn't run the gem's migrations" do
    allow(described_class).to receive(:migration_paths).and_return([])

    described_class.run!(primary_config)

    expect(connection.table_exists?(table)).to be(false)
  end

  describe "migration lock" do
    let(:migration_connection) { ActiveRecord::Tasks::DatabaseTasks.migration_connection }

    it "uses the same advisory lock id as ActiveRecord::Migrator" do
      skip "the database adapter has no current_database" unless migration_connection.respond_to?(:current_database)

      migrator = ActiveRecord::Migrator.new(:up, [], pool.schema_migration, pool.internal_metadata)

      expect(described_class.migration_lock_id(migration_connection))
        .to eq(migrator.send(:generate_migrator_advisory_lock_id))
    end

    it "holds the lock while removing recorded versions and running the migrations" do
      pool.schema_migration.create_version(version)
      held = 0
      max_held = 0
      allow(described_class).to receive(:migration_lock_id).and_return(42)
      allow_any_instance_of(ActiveRecord::Migrator).to receive(:generate_migrator_advisory_lock_id).and_return(42)
      allow(migration_connection).to receive(:advisory_locks_enabled?).and_return(true)
      allow(migration_connection).to receive(:get_advisory_lock).with(42) { held += 1; max_held = [ max_held, held ].max; true }
      allow(migration_connection).to receive(:release_advisory_lock) { held -= 1; true }
      allow_any_instance_of(ActiveRecord::SchemaMigration).to receive(:delete_version).and_wrap_original do |original, *args|
        expect(held).to be_positive
        original.call(*args)
      end

      described_class.run!(primary_config)

      # Released again, and Rails' migrator re-acquired it on the same
      # connection while the repair held it.
      expect(held).to eq(0)
      expect(max_held).to eq(2)
      expect(connection.table_exists?(table)).to be(true)
      expect(pool.schema_migration.versions).to include(version)
    end

    it "leaves recorded versions alone when another process holds the lock" do
      pool.schema_migration.create_version(version)
      allow(described_class).to receive(:migration_lock_id).and_return(42)
      allow(migration_connection).to receive_messages(advisory_locks_enabled?: true, get_advisory_lock: false)

      expect { described_class.run!(primary_config) }.to raise_error(ActiveRecord::ConcurrentMigrationError)
      expect(pool.schema_migration.versions).to include(version)
      expect(connection.table_exists?(table)).to be(false)
    end

    it "waits for a real concurrent session holding the migration lock" do
      skip "the database has no advisory locks" unless migration_connection.advisory_locks_enabled?

      pool.schema_migration.create_version(version)
      other_session = pool.checkout
      lock_id = described_class.migration_lock_id(other_session)
      expect(other_session.get_advisory_lock(lock_id)).to be(true)

      begin
        expect { described_class.run!(primary_config) }.to raise_error(ActiveRecord::ConcurrentMigrationError)
        expect(pool.schema_migration.versions).to include(version)
      ensure
        other_session.release_advisory_lock(lock_id)
        pool.checkin(other_session)
      end

      described_class.run!(primary_config)
      expect(connection.table_exists?(table)).to be(true)
    end
  end

  # Goes through ActiveRecord's real schema load (the path db:setup,
  # db:prepare and db:schema:load take) instead of calling run! directly.
  describe "ActiveRecord::Tasks::DatabaseTasks.load_schema" do
    let(:schema_table) { :newsmast_schema_load_host_table }

    it "runs the gem's migrations in the database the schema was loaded into" do
      skip "sqlite3 is not available" unless sqlite_available?

      Dir.mktmpdir do |dir|
        schema_file = File.join(dir, "schema.rb")
        File.write(schema_file, <<~RUBY)
          ActiveRecord::Schema[8.0].define(version: 2099_01_01_000000) do
            create_table :#{schema_table}, force: :cascade
          end
        RUBY

        # A primary database other than the one the suite is connected to.
        other_primary = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          "newsmast_schema_load_test", "primary",
          { "adapter" => "sqlite3", "database" => File.join(dir, "other.sqlite3") }
        )

        ActiveRecord::Tasks::DatabaseTasks.send(:with_temporary_pool, other_primary) do
          ActiveRecord::Tasks::DatabaseTasks.load_schema(other_primary, :ruby, schema_file)
        end

        ActiveRecord::Tasks::DatabaseTasks.send(:with_temporary_pool, other_primary) do |other_pool|
          other_pool.with_connection do |other_connection|
            expect(other_connection.table_exists?(schema_table)).to be(true)
            expect(other_connection.table_exists?(table)).to be(true)
          end
          expect(other_pool.schema_migration.versions).to include(version)
        end

        # The suite's own database is restored and untouched.
        expect(connection.table_exists?(table)).to be(false)
        expect(connection.table_exists?(schema_table)).to be(false)
      end
    end

    def sqlite_available?
      require "sqlite3"
      true
    rescue LoadError
      false
    end
  end
end

RSpec.describe NewsmastMastodon::SchemaLoadMigrations, ".migration_paths" do
  let(:gem_migrate_dir) { File.expand_path("../../../db/migrate", __dir__) }

  it "is empty when the app is not Mastodon, even though the engine appends its paths" do
    skip "runs only outside a Mastodon host" if defined?(HOST_ENVIRONMENT_LOADED) && HOST_ENVIRONMENT_LOADED

    # The dummy app gets the gem's paths too, but has no Mastodon migration
    # helpers, so replaying the gem's migrations there would fail.
    expect(Rails.application.config.paths["db/migrate"].expanded).to include(gem_migrate_dir)
    expect(described_class.mastodon_host?).to be(false)
    expect(described_class.migration_paths).to eq([])
  end

  it "discovers every gem migration in a Mastodon host" do
    require_host!

    expect(described_class.migration_paths).to eq([ gem_migrate_dir ])

    context = ActiveRecord::MigrationContext.new(described_class.migration_paths)
    expected = Dir[File.join(gem_migrate_dir, "*.rb")].map { |file| File.basename(file)[/\A\d+/].to_i }
    expect(context.migrations.map(&:version)).to match_array(expected)
  end

  it "created the gem's tables when the host test database was built from schema.rb" do
    require_host!

    # host-integration builds the host database with `db:prepare`, which
    # loads Mastodon's schema.rb and then runs the gem's migrations.
    connection = ActiveRecord::Base.lease_connection
    %i[patchwork_drafted_statuses patchwork_notification_tokens patchwork_settings patchwork_status_reactions].each do |gem_table|
      expect(connection.table_exists?(gem_table)).to be(true), "expected #{gem_table} to exist"
    end
  end
end
