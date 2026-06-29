# frozen_string_literal: true

require "newsmast_mastodon/version"
require "newsmast_mastodon/railtie" if defined?(Rails::Railtie)
require "newsmast_mastodon/engine" if defined?(Rails::Engine)
require "newsmast_mastodon/custom_relay_config"

module NewsmastMastodon
  class Error < StandardError; end
end
