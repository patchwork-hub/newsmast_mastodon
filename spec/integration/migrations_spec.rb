# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "Engine migrations", type: :integration do
  it "all 15 migrations run cleanly on a fresh database" do
    require_host!
    migration_dir = NewsmastMastodon::Engine.paths["db/migrate"].expanded.first
    files = Dir["#{migration_dir}/*.rb"]
    expect(files.size).to be >= 10
    files.each do |f|
      expect(File.basename(f)).to match(/\A\d+_.+\.rb\z/), "Migration file #{f} has unexpected name"
    end
  end

  it "ActiveRecord::Migration.check_all_pending! passes after maintain_test_schema!" do
    require_host!
    expect { ActiveRecord::Migration.check_all_pending! }.not_to raise_error
  end
end
