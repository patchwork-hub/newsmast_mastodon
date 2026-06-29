# frozen_string_literal: true

module NewsmastMastodon
  class Engine < ::Rails::Engine
    isolate_namespace NewsmastMastodon

    # --- Host Mastodon compatibility assertion ---
    # The gem is built and tested against an exact Mastodon runtime (declared in
    # newsmast_mastodon.gemspec as `mastodon_version_requirement`). Running it
    # against a different host version is the most common source of subtle
    # upgrade regressions, so surface a mismatch early: warn in development/test
    # and abort in production where silent drift is unacceptable.
    config.after_initialize do
      NewsmastMastodon::Engine.verify_host_mastodon_compatibility!
    end

    def self.verify_host_mastodon_compatibility!
      required = Gem.loaded_specs["newsmast_mastodon"]&.metadata&.fetch("mastodon_version_requirement", nil)
      return if required.nil?
      return unless defined?(::Mastodon::Version)

      actual = ::Mastodon::Version.to_s
      return if actual == required

      message = "[newsmast_mastodon] host Mastodon version mismatch: " \
                "gem targets #{required} but host reports #{actual}. " \
                "Pin the gem version that matches this Mastodon release " \
                "(see docs/internal/mastodon-upgrade/RUNBOOK.md)."

      if defined?(Rails) && Rails.env.production?
        abort(message)
      else
        Rails.logger&.warn(message)
        warn(message)
      end
    end

    # --- Doorkeeper password grant ---
    config.after_initialize do
      next unless defined?(Doorkeeper)

      Doorkeeper.configuration.instance_eval do
        @grant_flows = (@grant_flows || []) | [ "password" ]
        @resource_owner_from_credentials = proc do |_routes|
          user   = User.authenticate_with_ldap(email: request.params[:username], password: request.params[:password]) if Devise.ldap_authentication
          user ||= User.authenticate_with_pam(email: request.params[:username], password: request.params[:password]) if Devise.pam_authentication
          if user.nil?
            user = User.find_by(email: request.params[:username])
            user = nil unless user&.valid_password?(request.params[:password])
          end
          user unless user&.otp_required_for_login?
        end
      end
    end

    # --- Append migrations ---
    initializer :append_migrations do |app|
      unless app.root.to_s == root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    # --- Mount routes at "/" ---
    initializer "newsmast_mastodon.load_routes" do |app|
      app.routes.prepend do
        mount NewsmastMastodon::Engine => "/", :as => :newsmast_mastodon
      end
    end

    # --- Autoload paths for services, workers, presenters, validators ---
    config.autoload_paths << File.expand_path("../app/services", __FILE__)
    config.autoload_paths << File.expand_path("../app/workers", __FILE__)
    config.autoload_paths += %W[#{config.root}/app/presenters]
    config.autoload_paths += %W[#{config.root}/app/validators]

    # --- Ghost & WordPress webhook host allowlisting ---
    initializer "newsmast_mastodon.extend_allowed_hosts" do |app|
      allowed_hosts = []

      if ENV.values_at("GHOST_URL", "GHOST_WEBHOOK_TARGET_URL", "GHOST_WEBHOOK_SECRET").all?(&:present?)
        allowed_hosts << ENV["GHOST_URL"]
      end

      if ENV["WORDPRESS_URL"].present?
        allowed_hosts << ENV["WORDPRESS_URL"]
      end

      allowed_hosts.each do |host|
        clean_host = host.gsub(%r{^https?://}, "").split("/").first
        app.config.hosts << clean_host unless app.config.hosts.include?(clean_host)
      end
    end

    # --- Chewy autoload exclusion ---
    initializer "newsmast_mastodon.exclude_chewy_autoload", before: :set_autoload_paths do |app|
      gem_root = root.to_s
      chewy_path = File.join(gem_root, "app", "chewy", "newsmast_mastodon")
      config.autoload_paths.delete(chewy_path)
      config.eager_load_paths.delete(chewy_path)
      config.paths.add "app/chewy", with: []
      config.paths.add "app/chewy/newsmast_mastodon", with: []
    end

    # # --- Register custom relay sync in Sidekiq scheduler (without touching sidekiq.yml) ---
    # config.after_initialize do
    #   next unless defined?(Sidekiq)
    #   next unless Sidekiq.server?
    #   next unless defined?(SidekiqScheduler::Scheduler)

    #   schedule_name = 'newsmast_custom_relay_sync_scheduler'
    #   schedule_job = {
    #     'every' => ['5m'],
    #     'class' => 'NewsmastMastodon::RelayEnvSyncWorker',
    #     'queue' => 'scheduler',
    #   }

    #   # Preserve all host-defined schedules from sidekiq.yml and any currently
    #   # loaded runtime schedules, then layer in the gem schedule.
    #   host_schedule = begin
    #     config_path = Rails.root.join('config', 'sidekiq.yml')
    #     if File.exist?(config_path)
    #       raw = ERB.new(File.read(config_path)).result
    #       parsed = YAML.safe_load(raw, aliases: true) || {}
    #       parsed.fetch(':scheduler', {}).fetch(':schedule', {})
    #     else
    #       {}
    #     end
    #   rescue StandardError => e
    #     Rails.logger&.warn("[newsmast_mastodon] Failed to read sidekiq.yml schedule: #{e.message}")
    #     {}
    #   end

    #   runtime_schedule = Sidekiq.schedule || {}

    #   merged_schedule = host_schedule.to_h.transform_keys(&:to_s)
    #                                 .merge(runtime_schedule.to_h.transform_keys(&:to_s))
    #   merged_schedule[schedule_name] = schedule_job

    #   Sidekiq.schedule = merged_schedule
    #   SidekiqScheduler::Scheduler.instance.reload_schedule!

    #   Rails.logger&.info("[newsmast_mastodon] Sidekiq schedule registered: #{schedule_name}")
    # end

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
