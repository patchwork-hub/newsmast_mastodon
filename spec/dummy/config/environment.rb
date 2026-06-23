# Load the Rails application.
require_relative "application"

# Standalone specs rely on Mastodon host constant stubs during eager load.
require File.expand_path("../../support/mastodon_preboot_stubs", __dir__)

# Initialize the Rails application.
Rails.application.initialize!
