# frozen_string_literal: true

# SimpleCov must be required before any application code so it can track
# line coverage for the whole engine.
require "simplecov"

# SimpleCov 1.x (bundled by Mastodon 4.7 hosts) removed `SimpleCov.running`, so
# fall back to Ruby's own Coverage state to avoid starting coverage twice.
simplecov_running =
  if SimpleCov.respond_to?(:running)
    SimpleCov.running
  else
    require "coverage"
    Coverage.running?
  end

SimpleCov.start "rails" do
  add_filter "/spec/"
  add_filter "/test/"
  # CI can raise this gradually without breaking local contributor workflows.
  minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "0").to_i
end unless simplecov_running

# NOTE: newsmast_mastodon is loaded by the dummy app environment (via rails_helper),
# not here — requiring it before Rails would skip the engine due to the
# `if defined?(Rails::Engine)` guard in newsmast_mastodon.rb.

RSpec.configure do |config|
  # Prefer the non-monkey-patched syntax.
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.order = :random
  Kernel.srand config.seed
end
