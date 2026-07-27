# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe NewsmastMastodon::InstallationGuard do
  around do |example|
    Dir.mktmpdir do |dir|
      @rails_root = Pathname.new(dir)
      example.run
    end
  end

  it "raises when the host app has not completed installation" do
    expect do
      described_class.ensure_installed!(rails_root: @rails_root)
    end.to raise_error(NewsmastMastodon::InstallationError, /newsmast_mastodon:install/)
  end

  it "skips the guard while the install task is running" do
    original_program_name = $PROGRAM_NAME
    original_argv = ARGV.dup
    $PROGRAM_NAME = "rake"
    ARGV.replace(["newsmast_mastodon:install"])

    expect do
      described_class.ensure_installed!(rails_root: @rails_root)
    end.not_to raise_error
  ensure
    $PROGRAM_NAME = original_program_name
    ARGV.replace(original_argv)
  end

  it "allows boot when the marker and required files are present" do
    FileUtils.mkdir_p(@rails_root.join("app/chewy"))
    FileUtils.mkdir_p(@rails_root.join("app/javascript/mastodon/actions"))
    FileUtils.mkdir_p(@rails_root.join("app/javascript/mastodon/reducers"))
    FileUtils.mkdir_p(@rails_root.join("app/javascript/mastodon/features/compose/components"))
    FileUtils.mkdir_p(@rails_root.join("app/javascript/mastodon/features/compose/containers"))
    FileUtils.mkdir_p(@rails_root.join("app/javascript/mastodon/features/status/components"))
    FileUtils.mkdir_p(@rails_root.join("app/views/admin/shared"))

    FileUtils.touch(@rails_root.join(".newsmast_mastodon_installed"))
    FileUtils.touch(@rails_root.join("app/chewy/accounts_index.rb"))
    FileUtils.touch(@rails_root.join("app/chewy/statuses_index.rb"))
    FileUtils.touch(@rails_root.join("app/chewy/public_statuses_index.rb"))
    FileUtils.touch(@rails_root.join("app/javascript/mastodon/actions/compose.js"))
    FileUtils.touch(@rails_root.join("app/javascript/mastodon/reducers/compose.js"))
    FileUtils.touch(@rails_root.join("app/javascript/mastodon/features/compose/components/compose_form.jsx"))
    FileUtils.touch(@rails_root.join("app/javascript/mastodon/features/compose/containers/compose_form_container.js"))
    FileUtils.touch(@rails_root.join("app/javascript/mastodon/features/status/components/detailed_status.tsx"))
    FileUtils.touch(@rails_root.join("app/javascript/mastodon/features/compose/components/federated_dropdown.jsx"))
    FileUtils.touch(@rails_root.join("app/javascript/mastodon/features/compose/containers/federated_dropdown_container.js"))
    FileUtils.touch(@rails_root.join("app/views/admin/shared/_status.html.haml"))

    expect do
      described_class.ensure_installed!(rails_root: @rails_root)
    end.not_to raise_error
  end
end
