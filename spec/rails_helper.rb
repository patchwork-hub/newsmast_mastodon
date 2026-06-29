# frozen_string_literal: true

require "spec_helper"

ENV["RAILS_ENV"] ||= "test"

# Support two boot modes:
#
#   1. Standalone (gem's own Gemfile / dummy app) — default when running
#      `bundle exec rspec` from the gem root.  Loads the minimal dummy Rails app
#      and uses host-app stubs so specs can at least load.
#
#   2. Host-app mode (Mastodon's Gemfile) — triggered when BUNDLE_GEMFILE
#      points to a path containing "mastodon" (or MASTODON_ROOT is set).
#      Boots Mastodon's full Rails environment so DB, autoloading, and all
#      Mastodon constants are available.

unless defined?(MASTODON_ROOT)
  MASTODON_ROOT = ENV.fetch("MASTODON_ROOT") do
    gemfile = ENV["BUNDLE_GEMFILE"].to_s
    gemfile_dir = File.dirname(gemfile)
    # Only treat as host mode when the Gemfile lives directly inside a directory
    # named "mastodon" (e.g. /workspaces/mastodon/Gemfile).
    # This avoids false-positives for our own gem path (.../newsmast_mastodon/Gemfile).
    gemfile_dir if File.basename(gemfile) == "Gemfile" && File.basename(gemfile_dir) == "mastodon"
  end
end

if MASTODON_ROOT
  begin
    require "newsmast_mastodon"
  rescue LoadError
    # In host-bundle mode, this gem may not be listed in the host Gemfile.
    # Preload from local source before host Rails initializes.
    require "rails/engine"
    require File.expand_path("../lib/newsmast_mastodon", __dir__)
  end
end

host_environment_loaded = false
host_environment_path = File.join(MASTODON_ROOT.to_s, "config", "environment.rb")
strict_host_boot = ENV["NEWSMAST_STRICT_HOST_BOOT"] == "1"

if defined?(Rails) && Rails.application && Rails.application.initialized?
  # Already booted (e.g. nested require); nothing to do.
  host_environment_loaded = !MASTODON_ROOT.to_s.empty?
elsif !MASTODON_ROOT.to_s.empty? && File.exist?(host_environment_path)
  begin
    require host_environment_path
    host_environment_loaded = true
  rescue Exception => e
    raise if e.is_a?(SystemExit) || e.is_a?(SignalException) || e.is_a?(NoMemoryError)
    raise if strict_host_boot

    warn "[newsmast_mastodon/spec] Host boot failed at #{host_environment_path}: #{e.class}: #{e.message}"
    warn "[newsmast_mastodon/spec] Falling back to dummy Rails environment."
    require File.expand_path("dummy/config/environment", __dir__)
  end
elsif !MASTODON_ROOT.to_s.empty? && strict_host_boot
  abort("[newsmast_mastodon/spec] Strict host boot is enabled, but host environment file was not found: #{host_environment_path}")
else
  require File.expand_path("dummy/config/environment", __dir__)
end

abort("The Rails environment is running in production mode!") if Rails.env.production?

NEWSMAST_GEM_ROOT = File.expand_path("..", __dir__) unless defined?(NEWSMAST_GEM_ROOT)
HOST_ENVIRONMENT_LOADED = host_environment_loaded unless defined?(HOST_ENVIRONMENT_LOADED)

def standalone_sqlite_test_mode?
  !HOST_ENVIRONMENT_LOADED && ENV["DATABASE_URL"].blank? && ENV["DATABASE_HOST"].blank? && ENV["DATABASE_ADAPTER"].blank?
end

def bootstrap_standalone_test_database!
  sqlite_database = File.expand_path("dummy/db/test.sqlite3", __dir__)
  File.delete(sqlite_database) if File.exist?(sqlite_database)

  sqlite_config = {
    adapter: "sqlite3",
    database: sqlite_database
  }

  ActiveRecord::Base.configurations = {
    Rails.env => sqlite_config.stringify_keys
  }
  ActiveRecord::Base.establish_connection(sqlite_config)

  return if ActiveRecord::Base.connection.data_source_exists?("server_settings")

  ActiveRecord::Schema.verbose = false
  ActiveRecord::Schema.define do
    create_table :server_settings, force: true do |t|
      t.string :name
      t.string :optional_value
      t.boolean :value
      t.integer :position
      t.bigint :parent_id
      t.datetime :deleted_at
      t.timestamps null: false
    end
  end
end

bootstrap_standalone_test_database! if standalone_sqlite_test_mode?

require "rspec/rails"

# factory_bot_rails is in the gem's own bundle; the Mastodon host bundle uses
# Fabrication instead — skip gracefully if neither factory_bot variant is present.
begin
  require "factory_bot_rails"
rescue LoadError
  begin
    require "factory_bot"
  rescue LoadError
    # Running under Mastodon host bundle which uses Fabrication; no factory_bot.
  end
end

require "shoulda/matchers"
require "database_cleaner/active_record"

# Load host-app stubs only in standalone mode (when Mastodon classes are absent).
require File.expand_path("support/mastodon_stubs", __dir__) unless HOST_ENVIRONMENT_LOADED

require "webmock/rspec"

begin
  require "vcr"
rescue LoadError
  # vcr not available in the Mastodon host bundle; VCR.configure is skipped below.
end

require "faker"

# Ensure any pending migrations from the engine are run against the current DB.
unless standalone_sqlite_test_mode?
  begin
    ActiveRecord::Migration.maintain_test_schema!
  rescue ActiveRecord::PendingMigrationError => e
    warn e.to_s.strip
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
    # Dummy DB may not exist yet; pending specs can still load.
  end
end

# Load all support files (shared contexts, shared examples, helpers).
Dir[File.join(NEWSMAST_GEM_ROOT, "spec/support/**/*.rb")].each { |f| require f }

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

if defined?(VCR)
  VCR.configure do |config|
    config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
    config.hook_into :webmock
    config.configure_rspec_metadata!
    config.ignore_localhost = true
  end
end

RSpec.configure do |config|
  config.fixture_paths = [ File.join(NEWSMAST_GEM_ROOT, "spec/fixtures") ]
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods if defined?(FactoryBot)

  config.before(:suite) do
    DatabaseCleaner.strategy = standalone_sqlite_test_mode? ? :truncation : :transaction
    DatabaseCleaner.clean_with(:truncation) if ActiveRecord::Base.connected?
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
    # DB may not exist yet; pending specs can still load.
  end

  config.around do |example|
    if ActiveRecord::Base.connected?
      DatabaseCleaner.cleaning { example.run }
    else
      example.run
    end
  end
end
