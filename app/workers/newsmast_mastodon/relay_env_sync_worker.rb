# frozen_string_literal: true

module NewsmastMastodon
  # Sidekiq worker invoked by the scheduler to keep Relay records in sync
  # with the CUSTOM_RELAY_DOMAINS environment variable.
  #
  # Scheduled in config/sidekiq.yml:
  #
  #   newsmast_custom_relay_sync_scheduler:
  #     every: '5m'
  #     class: NewsmastMastodon::RelayEnvSyncWorker
  #     queue: scheduler
  #
  # Can also be triggered manually:
  #   NewsmastMastodon::RelayEnvSyncWorker.perform_async
  class RelayEnvSyncWorker
    include Sidekiq::Worker

    sidekiq_options queue: "scheduler", retry: 0,
                    lock: :until_executed,
                    lock_ttl: 5.minutes.to_i

    def perform
      NewsmastMastodon::SyncCustomRelaysService.new.call
    end
  end
end
