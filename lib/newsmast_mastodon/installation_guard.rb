# frozen_string_literal: true

require "pathname"

module NewsmastMastodon
  class InstallationError < StandardError; end

  module InstallationGuard
    module_function

    def ensure_installed!(rails_root: Rails.root)
      return true if install_task_running?

      root = Pathname.new(rails_root.to_s)
      marker_path = root.join(".newsmast_mastodon_installed")

      required_paths = [
        marker_path,
        root.join("app/chewy/accounts_index.rb"),
        root.join("app/chewy/statuses_index.rb"),
        root.join("app/chewy/public_statuses_index.rb"),
        root.join("app/javascript/mastodon/actions/compose.js"),
        root.join("app/javascript/mastodon/reducers/compose.js"),
        root.join("app/javascript/mastodon/features/compose/components/compose_form.jsx"),
        root.join("app/javascript/mastodon/features/compose/containers/compose_form_container.js"),
        root.join("app/javascript/mastodon/features/status/components/detailed_status.tsx"),
        root.join("app/javascript/mastodon/features/compose/components/federated_dropdown.jsx"),
        root.join("app/javascript/mastodon/features/compose/containers/federated_dropdown_container.js"),
        root.join("app/views/admin/shared/_status.html.haml")
      ]

      missing = required_paths.reject(&:exist?)
      return true if missing.empty?

      raise InstallationError, <<~MSG.squish
        newsmast_mastodon host installation is incomplete. Please run `bin/rails newsmast_mastodon:install`
        before starting the app, then restart after the Chewy indexes and frontend overrides have been copied.
      MSG
    end

    def install_task_running?
      return true if $PROGRAM_NAME.to_s.include?("rake")
      return true if ARGV.any? { |arg| install_task?(arg) }

      # `bin/rails <task>` hands ARGV to Rake before the environment loads, so
      # ARGV no longer contains the task name; ask Rake directly.
      rake_top_level_tasks.any? { |task| install_task?(task) }
    end

    def rake_top_level_tasks
      return [] unless defined?(Rake) && Rake.respond_to?(:application)

      Array(Rake.application.top_level_tasks)
    rescue StandardError
      []
    end

    def install_task?(name)
      name.to_s.include?("newsmast_mastodon:install")
    end
  end
end
