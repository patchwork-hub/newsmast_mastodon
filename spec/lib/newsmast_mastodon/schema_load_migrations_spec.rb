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
