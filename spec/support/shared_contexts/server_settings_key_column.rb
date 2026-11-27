# frozen_string_literal: true

# `server_settings.key` is added by the Newsmast Dashboard, not by this gem's
# migrations, and NewsmastMastodon::ServerSetting works with or without it.
# Examples that exercise the keyed lookup add the column for their duration
# when the database doesn't have it (for example a plain Mastodon host).
RSpec.shared_context "with the dashboard server_settings.key column" do
  around do |example|
    connection = nil
    added = false

    connection = NewsmastMastodon::ServerSetting.connection
    added = !connection.column_exists?(:server_settings, :key)

    if added
      connection.add_column(:server_settings, :key, :string)
      NewsmastMastodon::ServerSetting.reset_column_information
    end

    example.run
  ensure
    if added && connection
      connection.remove_column(:server_settings, :key) if connection.column_exists?(:server_settings, :key)
      NewsmastMastodon::ServerSetting.reset_column_information
    end
  end
end
