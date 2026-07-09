# frozen_string_literal: true

require_relative "lib/newsmast_mastodon/version"

Gem::Specification.new do |spec|
  spec.name        = "newsmast_mastodon"
  spec.version     = NewsmastMastodon::VERSION
  spec.authors     = [ "Aung Kyaw Phyo" ]
  spec.email       = [ "akp@binarylab.io" ]
  spec.homepage    = "https://github.com/TheNewsmastFoundation/newsmast-mastodon"
  spec.summary     = "A Ruby gem to extend Mastodon for Newsmast mobile apps and dashboard."
  spec.description = "The Newsmast Mastodon gem extends a Mastodon server to provide functionality for content filters, posts management, account management, content channels and more. The gem interacts with the Newsmast Apps for Change mobile apps - customised mobile apps for Newsmast Communities, and the Newsmast Dashboard, which allows extended customisation of Mastodon server features and settings."
  spec.license     = "AGPL-3.0-only"
  spec.required_ruby_version = ">= 3.2.0", "< 3.5.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/TheNewsmastFoundation/newsmast-mastodon"
  spec.metadata["changelog_uri"]     = "https://github.com/TheNewsmastFoundation/newsmast-mastodon/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]   = "https://github.com/TheNewsmastFoundation/newsmast-mastodon/issues"
  spec.metadata["mastodon_version_requirement"] = "4.5.11"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "CHANGELOG.md", "LICENSE.txt", "Rakefile", "README.md"]
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # Runtime dependencies
  spec.add_dependency "rails",            "~> 8.0.0"
  spec.add_dependency "googleauth",       "~> 1.13", ">= 1.13.1"
  spec.add_dependency "httparty",         "~> 0.23.1"
  spec.add_dependency "jwt",              "~> 2.10.0"
  spec.add_dependency "faraday",          "~> 2.14.0"
  spec.add_dependency "parslet",          "~> 2.0.0"

  # Development / test dependencies
  # NOTE: sidekiq is provided at runtime by the host Mastodon application and
  # is kept here only for local engine testing. Do not add it as a runtime
  # dependency unless the engine is intended to run standalone.
  spec.add_development_dependency "rspec-rails",               "~> 8.0.0"
  spec.add_development_dependency "factory_bot_rails",         "~> 6.4"
  spec.add_development_dependency "shoulda-matchers",          "~> 6.5.0"
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.2.0"
  spec.add_development_dependency "webmock",                   "~> 3.26.0"
  spec.add_development_dependency "vcr",                       "~> 6.3"
  spec.add_development_dependency "faker",                     "~> 3.5.0"
  spec.add_development_dependency "simplecov",                 "~> 0.22.0"
  spec.add_development_dependency "pg",                        "~> 1.6.0"
  spec.add_development_dependency "debug",                     "~> 1.11.0"
  spec.add_development_dependency "puma",                      "~> 7.1.0"
  spec.add_development_dependency "sidekiq",                   "~> 8.0.0"
  spec.add_development_dependency "sqlite3",                   "~> 2.1"
  spec.add_development_dependency "rubocop-rails-omakase"
end
