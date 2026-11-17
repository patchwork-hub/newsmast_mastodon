# frozen_string_literal: true

require "spec_helper"
require "yaml"

# Every host file that `newsmast_mastodon:install` overwrites must be listed in
# config/override_baselines.yml, otherwise `bin/check-override-drift` cannot
# warn when upstream changes the file on a Mastodon bump (RUNBOOK Phase E.4).
RSpec.describe "Override manifest completeness" do
  root          = File.expand_path("../..", __dir__)
  install_rake  = File.read(File.join(root, "lib/tasks/newsmast_mastodon/install.rake"))
  manifest      = YAML.safe_load_file(File.join(root, "config/override_baselines.yml")).fetch("overrides")
  manifest_paths = manifest.map { |entry| entry["path"] }

  # Frontend / view overrides: `target_root: Rails.root.join("<root>")` followed
  # by `"<source>" => "<target>"` mappings.
  installed_paths = []
  current_root = nil
  install_rake.each_line do |line|
    if (match = line.match(/target_root:\s*Rails\.root\.join\("([^"]+)"\)/))
      current_root = match[1]
    elsif current_root && (match = line.match(/"[^"]+"\s*=>\s*"([^"]+)"/))
      installed_paths << File.join(current_root, match[1])
    end
  end

  # Chewy indexes: every file under app/chewy/newsmast_mastodon/ is copied to
  # the host's app/chewy/.
  Dir.glob(File.join(root, "app/chewy/newsmast_mastodon/*.rb")).each do |file|
    installed_paths << File.join("app/chewy", File.basename(file))
  end

  it "finds the overrides installed by install.rake" do
    expect(installed_paths).to include(
      "app/javascript/mastodon/actions/compose.js",
      "app/views/admin/shared/_status.html.haml",
      "app/chewy/statuses_index.rb"
    )
  end

  installed_paths.uniq.each do |path|
    it "tracks #{path} in config/override_baselines.yml" do
      expect(manifest_paths).to include(path),
        "#{path} is installed by newsmast_mastodon:install but missing from " \
        "config/override_baselines.yml; add it and run bin/check-override-drift --update."
    end
  end

  it "records a baseline for every upstream override" do
    missing = manifest.select { |entry| entry["upstream"] && entry["baseline_sha256"].to_s.empty? }

    expect(missing.map { |entry| entry["path"] }).to be_empty
  end
end
