# frozen_string_literal: true

require "spec_helper"

# Guards every gem-shipped migration against the most common upgrade failure:
# a column/table the gem adds may already exist in the host Mastodon schema
# (either because upstream added it natively, or a prior gem version did).
#
# Every migration must therefore be idempotent. We enforce this statically by
# asserting that each `add_column` / `add_index` / `create_table` /
# `add_reference` is paired with an existence guard, so a single unguarded
# migration fails CI before it can break a host `db:migrate`.
RSpec.describe "Migration idempotency guards" do
  MIGRATION_DIR = File.expand_path("../../db/migrate", __dir__)

  # Operations that can collide with a pre-existing host schema and the guard
  # token that makes each one safe to re-run.
  GUARD_TOKENS = {
    "create_table"  => %w[if_not_exists table_exists?],
    "add_column"    => %w[column_exists? if_not_exists],
    "add_reference" => %w[column_exists? if_not_exists],
    "add_index"     => %w[if_not_exists index_exists?]
  }.freeze

  migration_files = Dir.glob(File.join(MIGRATION_DIR, "*.rb")).sort

  it "finds migration files to check" do
    expect(migration_files).not_to be_empty
  end

  migration_files.each do |path|
    name = File.basename(path)

    describe name do
      let(:source) { File.read(path) }

      GUARD_TOKENS.each do |operation, tokens|
        it "guards every #{operation} against pre-existing schema" do
          next unless source.match?(/^\s*#{Regexp.escape(operation)}\b/)

          guarded = tokens.any? { |token| source.include?(token) }

          expect(guarded).to(
            be(true),
            "#{name} calls `#{operation}` without an idempotency guard " \
            "(one of: #{tokens.join(', ')}). Gem migrations must be safe to " \
            "re-run against a host schema that may already have the column/table."
          )
        end
      end
    end
  end
end
