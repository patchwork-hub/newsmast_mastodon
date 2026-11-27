# frozen_string_literal: true

require "newsmast_mastodon/version"
require "newsmast_mastodon/railtie" if defined?(Rails::Railtie)
require "newsmast_mastodon/engine" if defined?(Rails::Engine)
require "newsmast_mastodon/migration_compatibility"
require "newsmast_mastodon/custom_relay_config"
require "newsmast_mastodon/installation_guard"
require "newsmast_mastodon/schema_load_migrations"

module NewsmastMastodon
  class Error < StandardError; end
end
