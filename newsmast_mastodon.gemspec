# frozen_string_literal: true

require_relative "lib/newsmast_mastodon/version"

Gem::Specification.new do |spec|
  spec.name        = "newsmast_mastodon"
  spec.version     = NewsmastMastodon::VERSION
  spec.authors     = ["Aung Kyaw Phyo"]
  spec.email       = ["kiru.kiru28@gmail.com"]
  spec.homepage    = "https://www.joinpatchwork.org/"
  spec.summary     = "Newsmast extensions for Mastodon — accounts, content filters, conversations, custom feeds, local-only posts, posting enhancements, and timeline extensions."
  spec.description = "A consolidated Rails engine gem that extends Mastodon with Newsmast features: custom registration flows, push notifications, content filtering, custom feeds, draft management, ALT text generation, local-only posts, and extended timelines."
  spec.license     = "AGPL-3.0-only"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/patchwork-hub/newsmast_mastodon"
  spec.metadata["changelog_uri"]     = "https://github.com/patchwork-hub/newsmast_mastodon/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]   = "https://github.com/patchwork-hub/newsmast_mastodon/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies (union of all 7 source gems)
  spec.add_dependency "rails",            ">= 7.1", "< 9.0"
  spec.add_dependency "byebug",           "~> 11.1"
  spec.add_dependency "googleauth",       "~> 1.13", ">= 1.13.1"
  spec.add_dependency "httparty",         "~> 0.23.1"
  spec.add_dependency "link_thumbnailer", "~> 3.4"
  spec.add_dependency "annotaterb",       "~> 4.13"

  # Development / test dependencies (Phase 12)
  spec.add_development_dependency "rspec-rails",               "~> 7.0"
  spec.add_development_dependency "factory_bot_rails",         "~> 6.4"
  spec.add_development_dependency "shoulda-matchers",          "~> 7.0"
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.2"
  spec.add_development_dependency "webmock",                   "~> 3.24"
  spec.add_development_dependency "vcr",                       "~> 6.3"
  spec.add_development_dependency "faker",                     "~> 3.5"
  spec.add_development_dependency "simplecov",                 "~> 0.22"
  spec.add_development_dependency "pg",                        "~> 1.5"
end
