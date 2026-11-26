# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe NewsmastMastodon::SchemaLoadMigrations do
  let(:version) { "20200101000001" }
  let(:table) { :newsmast_schema_load_probe }
  let(:pool) { ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool }
  let(:connection) { pool.lease_connection }
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
end
